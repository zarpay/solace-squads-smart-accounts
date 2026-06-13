---
title: Execute a Settings Transaction
---

# Execute a Settings Transaction

Applies the stored [`SettingsAction`](/reference/account-types)s of an **Approved**
settings-transaction proposal to the account — the actions are read from the stored
transaction on-chain, so this call takes no action arguments.

> The signer must hold the **Execute** permission and the proposal must be **Approved**
> (and past any time lock). A `rent_payer` is supplied because some actions (adding a
> signer, adding a spending limit) grow the settings account. Actions that
> add/remove a spending limit also need that limit's PDA in `spending_limit_accounts`,
> in action order.

## Program method — `execute_settings_transaction`

Signs with `payer` + `signer` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An Execute-holding member; must sign. |
| `transaction_index` | Integer | yes | — | Index of the settings transaction to apply. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings reallocation; must sign. |
| `spending_limit_accounts` | Array\<#to_s\> | no | `[]` | SpendingLimit PDAs touched by the actions, in action order. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.execute_settings_transaction(
  payer:             creator,
  settings:          identity.settings_address,
  signer:            creator,
  transaction_index: 1,
  rent_payer:        creator
)
```

## Composer — `SquadsSmartAccountsExecuteSettingsTransactionComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An Execute-holding member; must sign. |
| `proposal` | #to_s | yes | — | The Proposal PDA (must be Approved). |
| `transaction` | #to_s | yes | — | The SettingsTransaction PDA to apply. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings realloc; must sign. |
| `spending_limit_accounts` | Array\<#to_s\> | no | `[]` | SpendingLimit PDAs touched by the actions, in action order. |

```ruby
proposal,    = program.get_proposal_address(settings_address: identity.settings_address, transaction_index: 1)
transaction, = program.get_transaction_address(settings_address: identity.settings_address, transaction_index: 1)

composer = Solace::Composers::SquadsSmartAccountsExecuteSettingsTransactionComposer.new(
  settings:    identity.settings_address,
  signer:      creator.address,
  proposal:,
  transaction:,
  rent_payer:  creator.address
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[131, 210, 27, 88, 27, 204, 143, 189]`
- **Encodes (`data`):** the discriminator only — `executeSettingsTransaction` takes no arguments.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `signer_index` | Integer | yes | — | Index of the executing signer. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `transaction_index` | Integer | yes | — | Index of the SettingsTransaction PDA. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
| `spending_limit_indices` | Array\<Integer\> | no | `[]` | Indices of SpendingLimit PDAs, in action order. |
