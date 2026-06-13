---
title: Close a Transaction
---

# Close a Transaction

Closes a vault Transaction and its Proposal, refunding their rent. Use this to clean up
after a transaction reaches a terminal state.

> Closeable once the proposal is **Executed**, **Rejected**, or **Cancelled**, or is
> stale and not Approved. An Approved-but-unexecuted vault proposal **cannot** be closed
> — it can still execute. No member signature is required; only the fee payer signs.

## Program method — `close_transaction`

Signs with `payer` only, then sends. The rent collectors default to the on-chain stored
values (the proposal's and transaction's rent collectors) when omitted.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; the only signer. |
| `settings` | #to_s | yes | — | The settings account address. |
| `transaction_index` | Integer | yes | — | Index of the transaction to close. |
| `proposal_rent_collector` | #to_s | no | stored value | Receives the proposal rent (defaults to the proposal's stored collector). |
| `transaction_rent_collector` | #to_s | no | stored value | Receives the transaction rent (defaults to the transaction's stored collector). |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.close_transaction(
  payer:             creator,
  settings:          identity.settings_address,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsCloseTransactionComposer`

The rent collectors must be resolved (the program method reads them from the on-chain
proposal and transaction).

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `proposal` | #to_s | yes | — | The Proposal PDA to close. |
| `transaction` | #to_s | yes | — | The vault Transaction PDA to close. |
| `proposal_rent_collector` | #to_s | yes | — | Receives the proposal rent. |
| `transaction_rent_collector` | #to_s | yes | — | Receives the transaction rent (must equal `transaction.rent_collector`). |

```ruby
proposal,    = program.get_proposal_address(settings_address: identity.settings_address, transaction_index: 1)
transaction, = program.get_transaction_address(settings_address: identity.settings_address, transaction_index: 1)

composer = Solace::Composers::SquadsSmartAccountsCloseTransactionComposer.new(
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

- **Discriminator:** `[97, 46, 152, 170, 42, 215, 192, 218]`
- **Encodes (`data`):** the discriminator only — `closeTransaction` takes no arguments.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `transaction_index` | Integer | yes | — | Index of the Transaction PDA. |
| `proposal_rent_collector_index` | Integer | yes | — | Index of the proposal rent collector. |
| `transaction_rent_collector_index` | Integer | yes | — | Index of the transaction rent collector. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
