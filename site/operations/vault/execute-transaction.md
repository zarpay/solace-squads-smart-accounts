---
title: Execute a Transaction
---

# Execute a Transaction

Runs the inner instructions of an **Approved** proposal's stored transaction — the
final step of [the async lifecycle](/concepts/async-transaction-lifecycle). The program
signs the inner instructions **as the vault PDA** via CPI, so the funds move under the
account's control.

> The signer must hold the **Execute** permission, the proposal must be **Approved**,
> and the settings `time_lock` must have elapsed since approval. The vault is the
> message's signer but a PDA, so it is never passed as a transaction signer.

## Program method — `execute_transaction`

Signs with `payer` + `signer`, then sends. The method fetches the stored Transaction to
reconstruct its account list and derives the vault, Proposal, and Transaction PDAs for
you.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An Execute-holding member; must sign. |
| `transaction_index` | Integer | yes | — | Index of the transaction to execute. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.execute_transaction(
  payer:             member,
  settings:          identity.settings_address,
  signer:            member,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsExecuteTransactionComposer`

The composer needs the stored message's account metas (from
`program.get_transaction(...).account_metas`) and the vault address, which it appends
as the instruction's remaining accounts.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `proposal` | #to_s | yes | — | The Proposal PDA (must be Approved). |
| `transaction` | #to_s | yes | — | The Transaction PDA to execute. |
| `signer` | #to_s · Keypair | yes | — | An Execute-holding member; must sign. |
| `smart_account` | #to_s | yes | — | The vault PDA the message spends from (forced non-signer). |
| `account_metas` | Array\<Hash\> | yes | — | The stored message's account metas, in order — each `{ pubkey:, signer:, writable: }` (from `Transaction#account_metas`). |

```ruby
proposal,    = program.get_proposal_address(settings_address: identity.settings_address, transaction_index: 1)
transaction, = program.get_transaction_address(settings_address: identity.settings_address, transaction_index: 1)
stored       = program.get_transaction(transaction_address: transaction)

composer = Solace::Composers::SquadsSmartAccountsExecuteTransactionComposer.new(
  settings:      identity.settings_address,
  proposal:,
  transaction:,
  signer:        member.address,
  smart_account: identity.smart_account_address,
  account_metas: stored.account_metas
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(member)
                                .compose_transaction

tx.sign(member)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[231, 173, 49, 91, 235, 24, 68, 19]`
- **Encodes (`data`):** the discriminator only — `executeTransaction` takes no arguments.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `transaction_index` | Integer | yes | — | Index of the Transaction PDA. |
| `signer_index` | Integer | yes | — | Index of the executing signer. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
| `remaining_account_indices` | Array\<Integer\> | yes | — | Indices of the stored message's `account_keys`, in order, appended after the fixed accounts. |
