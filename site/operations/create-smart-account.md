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
transaction fails cleanly with `MissingAccount` — re-fetch and retry.

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

## Composer — `SquadsSmartAccountsCreateSmartAccountComposer`

Use the composer when you want control over the fee payer and signing, or to batch
this with other instructions. The treasury and settings address must be resolved
first (the program method does this for you via `get_program_config` and
`get_settings_address`).

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `creator` | #to_s | yes | — | Base58 pubkey creating the account. |
| `treasury` | #to_s | yes | — | Treasury pubkey, from `program.get_program_config.treasury`. |
| `settings` | #to_s | yes | — | The settings PDA to create — from `get_settings_address`. |
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
| `settings_index` | Integer | yes | — | Index of the settings PDA. |

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
