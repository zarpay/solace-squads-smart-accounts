---
title: Execute a Transaction Synchronously
---

# Execute a Transaction Synchronously

Executes inner instructions out of a vault in a **single transaction** — no stored
transaction, proposal, or voting lifecycle. The outer transaction must carry enough
co-signatures to reach the [threshold](/concepts/permissions-and-threshold); the
program then signs the inner instructions as the vault PDA via CPI.

> Use this when the signers are all available at once and you don't need an on-chain
> proposal record. For the full propose → vote → execute flow, use
> [`create_transaction`](/operations/vault/create-transaction) and friends. The vault
> is a message signer but a PDA, so it is never passed as a transaction signer.

## Program method — `execute_transaction_sync`

Signs with `payer` + each of `signers`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `smart_account` | #to_s | yes | — | The vault PDA the inner instructions spend from. |
| `signers` | Array\<#to_s · Keypair\> | yes | — | Co-signers proving threshold consensus; must sign. |
| `instructions` | Array\<Composers::Base\> | yes | — | Inner instruction composers. |
| `account_index` | Integer | no | `0` | Vault index the `smart_account` was derived with. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
recipient = Solace::Keypair.generate

program.execute_transaction_sync(
  payer:         creator,
  settings:      identity.settings_address,
  smart_account: identity.smart_account_address,
  signers:       [creator],
  instructions:  [
    Solace::Composers::SystemProgramTransferComposer.new(
      from:     identity.smart_account_address,
      to:       recipient.address,
      lamports: 250_000_000
    )
  ]
)
```

## Composer — `SquadsSmartAccountsExecuteTransactionSyncComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `smart_account` | #to_s | yes | — | The vault PDA the inner instructions spend from. |
| `signers` | Array\<#to_s\> | yes | — | Co-signer pubkeys, exactly enough to reach the threshold. |
| `instructions` | Array\<Composers::Base\> | yes | — | Inner instruction composers. |
| `account_index` | Integer | no | `0` | Vault index the `smart_account` was derived with. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsExecuteTransactionSyncComposer.new(
  settings:      identity.settings_address,
  smart_account: identity.smart_account_address,
  signers:       [creator.address],
  instructions:  [
    Solace::Composers::SystemProgramTransferComposer.new(
      from:     identity.smart_account_address,
      to:       recipient.address,
      lamports: 250_000_000
    )
  ]
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[43, 102, 248, 89, 231, 97, 104, 134]`
- **Encodes (`data`):** `account_index` + `num_signers` + `bytes(compiled_instructions)` (the inner instructions serialized as a SmallVec, embedded as a Borsh bytes field)

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `account_index` | Integer | yes | — | Vault index. |
| `num_signers` | Integer | yes | — | Number of co-signers. |
| `instructions` | Array\<Solace::Instruction\> | yes | — | Compiled inner instructions (resolved against the full remaining-accounts context). |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
| `signer_indices` | Array\<Integer\> | yes | — | Indices of the co-signers (the leading remaining accounts). |
| `remaining_account_indices` | Array\<Integer\> | yes | — | Indices of the inner-instruction accounts (after the signers). |
