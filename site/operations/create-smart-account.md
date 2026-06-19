---
title: Create a Smart Account
---

# Create a Smart Account

Creates a new **Settings** account — the control plane that defines the signer set,
threshold, and time lock. The smart account's vaults are dataless PDAs derived from
it, so no vault is created here (see [Settings vs. Smart Account](/concepts/settings-vs-smart-account)).

The settings PDA is derived from a seed equal to the program config's running index
+ 1, so derive the next identity with [`next_smart_account`](/reference/pda-and-fetchers)
first and pass its seed. If another account is created before yours lands, the
transaction fails cleanly with `MissingAccount` — re-fetch and retry, or avoid the
race entirely with a [candidate window](#race-free-creation-with-a-window).

## Program method — `create_smart_account`

The one-call path: derives the settings PDA and treasury, builds, signs (`payer` +
`creator`), and sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee, the settings-account rent, and the program's creation fee; co-signs. |
| `settings_seed` | Integer | yes | — | Seed for the settings PDA — use `next_smart_account.settings_seed`. |
| `creator` | #to_s · Keypair | yes | — | The account creating the smart account; co-signs. Need not be a member. |
| `threshold` | Integer | yes | — | Approvals required to execute a transaction. Must be ≥ 1 and ≤ the number of Vote-holding signers. |
| `signers` | Array\<SmartAccountSigner\> | yes | — | Initial members and their permission masks. Must include ≥ 1 each of Initiate, Vote, Execute. |
| `window` | Integer | no | `1` | Number of consecutive candidate settings PDAs to offer. `> 1` makes creation [race-free](#race-free-creation-with-a-window). |
| `time_lock` | Integer | no | `0` | Seconds between a proposal's approval and when it may execute. |
| `settings_authority` | #to_s | no | `nil` | Reconfiguration authority for a **controlled** account. Omit (`nil`) for an **autonomous** account. |
| `rent_collector` | #to_s | no | `nil` | Pubkey that reclaims rent when accounts are closed. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
identity = program.next_smart_account

program.create_smart_account(
  payer:         creator,
  settings_seed: identity.settings_seed,
  creator:,
  threshold:     1,
  signers:       [
    Solace::SquadsSmartAccounts::SmartAccountSigner.new(
      pubkey:     creator.address,
      permission: Solace::SquadsSmartAccounts::Permissions::ALL
    )
  ]
)
```

## Race-free creation with a window

The deterministic path bets on a single seed (`index + 1`). Under concurrency that
bet loses: if other smart accounts are created between your `get_program_config`
read and your transaction landing, the program's incremented index no longer matches
your one derived PDA and the transaction fails with `MissingAccount`.

To create race-free, pass `window:` to **offer a window of consecutive candidate
PDAs** (seeds `index+1 … index+window`). The program increments its counter and
initializes whichever candidate matches the new value — so the transaction succeeds
as long as the true index lands inside the window, no matter how many accounts were
created concurrently. This mirrors how the Squads team's own SDK creates accounts.

Because the winning address isn't known until the transaction lands, resolve it
afterward from the emitted event with
[`get_created_smart_account_event`](/reference/pda-and-fetchers#get-created-smart-account-event),
then match it back to your candidates to recover the seed and vault.

```ruby
# 1. Derive the window of possible identities (persist these if indexing).
candidates = program.next_smart_account_candidates(count: 20)

# 2. Offer the whole window. Creation succeeds even if other accounts are
#    created before this transaction lands.
tx = program.create_smart_account(
  payer:         creator,
  settings_seed: candidates.first.settings_seed,
  window:        20,
  creator:,
  threshold:     1,
  signers:       [
    Solace::SquadsSmartAccounts::SmartAccountSigner.new(
      pubkey:     creator.address,
      permission: Solace::SquadsSmartAccounts::Permissions::ALL
    )
  ]
)
connection.wait_for_confirmed_signature { tx.signature }

# 3. Resolve which candidate the program actually created.
event    = program.get_created_smart_account_event(signature: tx.signature)
identity = candidates.find { |c| c.settings_address == event.new_settings_pubkey }

identity.settings_seed         # => the seed the program landed on (index it bumped to)
identity.settings_address      # => event.new_settings_pubkey
identity.smart_account_address # => its default vault
```

The integration suite confirms this end-to-end: with a window in flight, creating
several more accounts out-of-band first, the program lands the new settings account
on the candidate at the drifted offset, and the event returns exactly that seed
(index) and address.

::: tip
Only winning candidate is ever initialized — the unused candidates cost transaction
size, not rent. A window of ~20 absorbs heavy concurrency while staying well under
the transaction account limit.
:::

## Composer — `SquadsSmartAccountsCreateSmartAccountComposer`

Use the composer when you want control over the fee payer and signing, or to batch
this with other instructions. The treasury and settings address must be resolved
first (the program method does this for you via `get_program_config` and
`get_settings_address`).

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `creator` | #to_s | yes | — | Base58 pubkey creating the account. |
| `treasury` | #to_s | yes | — | Treasury pubkey, from `program.get_program_config.treasury`. |
| `settings` | #to_s · Array\<#to_s\> | yes | — | The settings PDA to create — from `get_settings_address`. Pass an array (a candidate window) for [race-free creation](#race-free-creation-with-a-window). |
| `threshold` | Integer | yes | — | Approvals required to execute. |
| `signers` | Array\<SmartAccountSigner\> | yes | — | Initial members + permission masks. |
| `time_lock` | Integer | yes | — | Seconds between approval and execution (`0` to disable). |
| `settings_authority` | #to_s | no | `nil` | Reconfiguration authority (controlled account); `nil` ⇒ autonomous. |
| `rent_collector` | #to_s | no | `nil` | Rent-reclaim pubkey. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
program_config    = program.get_program_config
settings_address, = program.get_settings_address(settings_seed: identity.settings_seed)

composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
  creator:   creator.address,
  treasury:  program_config.treasury,
  settings:  settings_address,
  threshold: 1,
  signers:   [
    Solace::SquadsSmartAccounts::SmartAccountSigner.new(
      pubkey:     creator.address,
      permission: Solace::SquadsSmartAccounts::Permissions::ALL
    )
  ],
  time_lock: 0
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

`CreateSmartAccountInstruction.build` encodes the raw instruction. Account positions
are indices into the compiled message's `AccountContext` (the composer resolves these
with `context.index_of(...)`).

- **Discriminator:** `[197, 102, 253, 231, 77, 84, 50, 17]`
- **Encodes (`data`):** `option_pubkey(settings_authority)` + `le_u16(threshold)` + `smart_account_signers(signers)` + `le_u32(time_lock)` + `option_pubkey(rent_collector)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings_authority` | #to_s, nil | yes | — | Reconfiguration authority, or `nil` for autonomous. |
| `threshold` | Integer | yes | — | Approvals required. |
| `signers` | Array\<SmartAccountSigner\> | yes | — | Members + permission masks. |
| `time_lock` | Integer | yes | — | Seconds before execution. |
| `rent_collector` | #to_s, nil | yes | — | Rent-reclaim pubkey, or `nil`. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `program_config_index` | Integer | yes | — | Index of the ProgramConfig account. |
| `treasury_index` | Integer | yes | — | Index of the treasury account. |
| `creator_index` | Integer | yes | — | Index of the creator. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program (the invoked program). |
| `settings_index` | Integer · Array\<Integer\> | yes | — | Index of the settings PDA, or an array of candidate indices (the window) appended as remaining accounts. |

```ruby
ix = Solace::SquadsSmartAccounts::Instructions::CreateSmartAccountInstruction.build(
  settings_authority:   nil,
  threshold:            1,
  signers:              signers,
  time_lock:            0,
  rent_collector:       nil,
  memo:                 nil,
  program_config_index: context.index_of(Solace::SquadsSmartAccounts::PROGRAM_CONFIG_ADDRESS),
  treasury_index:       context.index_of(treasury),
  creator_index:        context.index_of(creator.address),
  system_program_index: context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
  program_index:        context.index_of(Solace::SquadsSmartAccounts::PROGRAM_ID),
  settings_index:       context.index_of(settings_address)
)
```
