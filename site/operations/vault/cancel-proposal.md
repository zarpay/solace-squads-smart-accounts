---
title: Cancel a Proposal
---

# Cancel a Proposal

Casts a cancellation vote on an **Approved** proposal — a way to call off a transaction
that was approved but not yet executed. Once cancellations reach the threshold, the
proposal becomes **Cancelled** (terminal) and should be
[closed](/operations/vault/close-transaction).

> The signer must hold the **Vote** permission, and the proposal must currently be
> **Approved**. Unlike approve/reject, this instruction requires the System program
> account (it may grow the proposal to record the cancellation).

## Program method — `cancel_proposal`

Signs with `payer` + `signer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | A Vote-holding member; must sign. |
| `transaction_index` | Integer | yes | — | Index of the proposal's transaction. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.cancel_proposal(
  payer:             member,
  settings:          identity.settings_address,
  signer:            member,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsCancelProposalComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | A Vote-holding member; must sign. |
| `proposal` | #to_s | yes | — | The Proposal PDA to cancel (must be Approved). |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
proposal, = program.get_proposal_address(
  settings_address:  identity.settings_address,
  transaction_index: 1
)

composer = Solace::Composers::SquadsSmartAccountsCancelProposalComposer.new(
  settings: identity.settings_address,
  signer:   member.address,
  proposal:
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(member)
                                .compose_transaction

tx.sign(member)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[106, 74, 128, 146, 19, 65, 39, 23]`
- **Encodes (`data`):** `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `signer_index` | Integer | yes | — | Index of the voting signer. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `system_program_index` | Integer | yes | — | Index of the System program (required for cancel). |
| `program_index` | Integer | yes | — | Index of the Squads program. |
