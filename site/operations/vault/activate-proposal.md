---
title: Activate a Proposal
---

# Activate a Proposal

Moves a proposal from **Draft** to **Active** so it can be voted on. Only needed for
proposals created with `draft: true`; the common path
([`create_proposal`](/operations/vault/create-proposal) with `draft: false`) skips
this and starts Active.

> The signer must hold the **Initiate** permission, and the proposal must currently be
> Draft. This is the one proposal instruction with **no trailing `program` account**.

## Program method — `activate_proposal`

Signs with `payer` + `signer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `transaction_index` | Integer | yes | — | Index of the proposal's transaction. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.activate_proposal(
  payer:             creator,
  settings:          identity.settings_address,
  signer:            creator,
  transaction_index: 1
)
```

## Composer — `SquadsSmartAccountsActivateProposalComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `proposal` | #to_s | yes | — | The Proposal PDA to activate. |

```ruby
proposal, = program.get_proposal_address(
  settings_address:  identity.settings_address,
  transaction_index: 1
)

composer = Solace::Composers::SquadsSmartAccountsActivateProposalComposer.new(
  settings: identity.settings_address,
  signer:   creator.address,
  proposal:
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[90, 186, 203, 234, 70, 185, 191, 21]`
- **Encodes (`data`):** the discriminator only — `activateProposal` takes no arguments.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `signer_index` | Integer | yes | — | Index of the activating signer. |
| `proposal_index` | Integer | yes | — | Index of the Proposal PDA. |
| `program_index` | Integer | yes | — | Index of the Squads program (the invoked program). |

> Note: the three accounts are `settings`, `signer`, `proposal` — there is **no**
> trailing `program` account in the account-metas list (unlike the other proposal
> instructions); the program is only the invoked program.
