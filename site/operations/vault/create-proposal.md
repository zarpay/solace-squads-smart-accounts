---
title: Create a Proposal
---

# Create a Proposal

Opens the voting record for a stored [transaction](/operations/vault/create-transaction).
A proposal created with `draft: false` (the default) starts **Active** and is ready to
vote on; `draft: true` starts **Draft** and must be [activated](/operations/vault/activate-proposal)
first.

> The creator must hold the **Initiate** permission. A proposal is 1:1 with its
> transaction (both derived from the same index). See
> [the async lifecycle](/concepts/async-transaction-lifecycle).

## Program method — `create_proposal`

Signs with `payer` + `creator` + `rent_payer`, then sends. The Proposal PDA is derived
from the settings address and transaction index.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `creator` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the Proposal account's rent; must sign. |
| `transaction_index` | Integer | yes | — | Index of the transaction this proposal tracks. |
| `draft` | Boolean | no | `false` | Start as Draft (needs activation) instead of Active. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.create_proposal(
  payer:             creator,
  settings:          identity.settings_address,
  creator:,
  rent_payer:        creator,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsCreateProposalComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `proposal` | #to_s | yes | — | The Proposal PDA to create (from `get_proposal_address`). |
| `creator` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the account's rent; must sign. |
| `transaction_index` | Integer | yes | — | Index of the tracked transaction. |
| `draft` | Boolean | no | `false` | Start as Draft instead of Active. |

```ruby
proposal, = program.get_proposal_address(
  settings_address:  identity.settings_address,
  transaction_index: 1
)

composer = Solace::Composers::SquadsSmartAccountsCreateProposalComposer.new(
  settings:          identity.settings_address,
  proposal:,
  creator:           creator.address,
  rent_payer:        creator.address,
  transaction_index: 1
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[132, 116, 68, 174, 216, 160, 198, 22]`
- **Encodes (`data`):** `le_u64(transaction_index)` + `bool(draft)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `transaction_index` | Integer | yes | — | Index of the tracked transaction. |
| `draft` | Boolean | yes | — | Start as Draft instead of Active. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `creator_index` | Integer | yes | — | Index of the creator. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
