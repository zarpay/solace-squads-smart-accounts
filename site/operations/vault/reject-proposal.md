---
title: Reject a Proposal
---

# Reject a Proposal

Casts a rejection vote on an **Active** proposal. Once rejections reach the cutoff
(`num_voters − threshold + 1`), the proposal becomes **Rejected** — a terminal state;
its transaction can never execute and should be [closed](/operations/vault/close-transaction).

> The signer must hold the **Vote** permission. A signer may switch a prior approval to
> a rejection. See [Permissions & Threshold](/concepts/permissions-and-threshold) for
> the cutoff math.

## Program method — `reject_proposal`

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
program.reject_proposal(
  payer:             member,
  settings:          identity.settings_address,
  signer:            member,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsRejectProposalComposer`

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

composer = Solace::Composers::SquadsSmartAccountsRejectProposalComposer.new(
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

- **Discriminator:** `[114, 162, 164, 82, 191, 11, 102, 25]`
- **Encodes (`data`):** `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `signer_index` | Integer | yes | — | Index of the voting signer. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `system_program_index` | Integer | yes | — | The optional systemProgram slot — fill with the program id when absent. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

> Shares the `VoteOnProposal` account layout with [approve](/operations/vault/approve-proposal);
> only the discriminator differs. `systemProgram` is absent, so its slot carries the
> Squads program id.
