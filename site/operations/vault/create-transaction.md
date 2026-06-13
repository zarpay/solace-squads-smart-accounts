---
title: Create a Transaction
---

# Create a Transaction

Stores a set of inner instructions on-chain as a pending **vault transaction** — it
does not execute yet. This is step one of [the async lifecycle](/concepts/async-transaction-lifecycle):
the transaction awaits a proposal and approvals before it can run.

> The creator must hold the **Initiate** permission. The transaction is stored at the
> settings account's `transaction_index + 1`; the program derives that index and the
> Transaction PDA for you. Scope: simple messages only — no Address Lookup Tables or
> ephemeral signers.

## Program method — `create_transaction`

Signs with `payer` + `creator` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `creator` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the Transaction account's rent; must sign. |
| `instructions` | Array\<Composers::Base\> | yes | — | Inner instruction composers (e.g. a `SystemProgramTransferComposer` spending from the vault). |
| `account_index` | Integer | no | `0` | Vault index the inner message spends from. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
recipient = Solace::Keypair.generate

program.create_transaction(
  payer:        creator,
  settings:     identity.settings_address,
  creator:,
  rent_payer:   creator,
  instructions: [
    Solace::Composers::SystemProgramTransferComposer.new(
      from:     identity.smart_account_address,
      to:       recipient.address,
      lamports: 250_000_000
    )
  ]
)
```

## Composer — `SquadsSmartAccountsCreateTransactionComposer`

The composer compiles the inner instructions into the stored message itself. The
Transaction PDA must be resolved first (the program method derives it from the next
index).

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `transaction` | #to_s | yes | — | The Transaction PDA to create (from `get_transaction_address`). |
| `creator` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the account's rent; must sign. |
| `instructions` | Array\<Composers::Base\> | yes | — | Inner instruction composers. |
| `account_index` | Integer | no | `0` | Vault index the message spends from. |
| `ephemeral_signers` | Integer | no | `0` | Ephemeral signer count (only `0` is supported). |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
transaction, = program.get_transaction_address(
  settings_address:  identity.settings_address,
  transaction_index: 1
)

composer = Solace::Composers::SquadsSmartAccountsCreateTransactionComposer.new(
  settings:     identity.settings_address,
  transaction:,
  creator:      creator.address,
  rent_payer:   creator.address,
  instructions: [
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

The deployed program models the args as a `TransactionPayload` enum and requires a
trailing `program` account — both reflected here.

- **Discriminator:** `[227, 193, 53, 239, 55, 126, 112, 105]`
- **Encodes (`data`):** `[0]` (TransactionPayload variant) + `account_index` + `ephemeral_signers` + `bytes(transaction_message)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `account_index` | Integer | yes | — | Vault index the message spends from. |
| `ephemeral_signers` | Integer | yes | — | Ephemeral signer count (`0`). |
| `transaction_message` | Array\<Integer\> | yes | — | The serialized compiled message bytes. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `transaction_index` | Integer | yes | — | Index of the Transaction PDA. |
| `creator_index` | Integer | yes | — | Index of the creator. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
