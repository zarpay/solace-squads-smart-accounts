---
title: Close a Settings Transaction
---

# Close a Settings Transaction

Closes a SettingsTransaction and its Proposal, refunding their rent. Clean-up after a
settings transaction reaches a terminal state.

> Closeable once the proposal is **Executed**, **Rejected**, or **Cancelled**, or is
> stale. (Unlike vault transactions, an Approved-but-stale settings proposal *can* be
> closed — it can no longer execute.) No member signature is required; only the fee
> payer signs.

## Program method — `close_settings_transaction`

Signs with `payer` only, then sends. The rent collectors default to the on-chain stored
values when omitted.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; the only signer. |
| `settings` | #to_s | yes | — | The settings account address. |
| `transaction_index` | Integer | yes | — | Index of the settings transaction to close. |
| `proposal_rent_collector` | #to_s | no | stored value | Receives the proposal rent (defaults to the proposal's stored collector). |
| `transaction_rent_collector` | #to_s | no | stored value | Receives the transaction rent (defaults to the transaction's stored collector). |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.close_settings_transaction(
  payer:             creator,
  settings:          identity.settings_address,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsCloseSettingsTransactionComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `proposal` | #to_s | yes | — | The Proposal PDA to close. |
| `transaction` | #to_s | yes | — | The SettingsTransaction PDA to close. |
| `proposal_rent_collector` | #to_s | yes | — | Receives the proposal rent. |
| `transaction_rent_collector` | #to_s | yes | — | Receives the transaction rent (must equal `transaction.rent_collector`). |

```ruby
proposal,    = program.get_proposal_address(settings_address: identity.settings_address, transaction_index: 1)
transaction, = program.get_transaction_address(settings_address: identity.settings_address, transaction_index: 1)

composer = Solace::Composers::SquadsSmartAccountsCloseSettingsTransactionComposer.new(
  settings:                   identity.settings_address,
  proposal:,
  transaction:,
  proposal_rent_collector:    creator.address,
  transaction_rent_collector: creator.address
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[251, 112, 34, 108, 214, 13, 41, 116]`
- **Encodes (`data`):** the discriminator only — `closeSettingsTransaction` takes no arguments.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `transaction_index` | Integer | yes | — | Index of the SettingsTransaction PDA. |
| `proposal_rent_collector_index` | Integer | yes | — | Index of the proposal rent collector. |
| `transaction_rent_collector_index` | Integer | yes | — | Index of the transaction rent collector. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
