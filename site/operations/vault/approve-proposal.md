---
title: Approve a Proposal
---

# Approve a Proposal

Casts an approval vote on an **Active** proposal. Once approvals reach the settings
[threshold](/concepts/permissions-and-threshold), the proposal becomes **Approved** and
its transaction can be [executed](/operations/vault/execute-transaction) (after any
time lock).

> The signer must hold the **Vote** permission. A signer may switch a prior rejection
> to an approval — the program removes the opposing vote. See
> [the async lifecycle](/concepts/async-transaction-lifecycle).

## Program method — `approve_proposal`

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
program.approve_proposal(
  payer:             member,
  settings:          identity.settings_address,
  signer:            member,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsApproveProposalComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | A Vote-holding member; must sign. |
| `proposal` | #to_s | yes | — | The Proposal PDA to vote on. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
proposal, = program.get_proposal_address(
  settings_address:  identity.settings_address,
  transaction_index: 1
)

composer = Solace::Composers::SquadsSmartAccountsApproveProposalComposer.new(
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

- **Discriminator:** `[136, 108, 102, 85, 98, 114, 7, 147]`
- **Encodes (`data`):** `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `signer_index` | Integer | yes | — | Index of the voting signer. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `system_program_index` | Integer | yes | — | The optional systemProgram slot — fill with the program id when absent. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

> `systemProgram` is optional for a vote and absent here, so its slot is filled with
> the Squads program id (Anchor's convention for an absent optional account).
