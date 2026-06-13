---
title: Remove a Spending Limit
---

# Remove a Spending Limit

Closes a [spending limit](/concepts/spending-limits) on a **controlled** account,
authorized by the settings authority. The closed account's rent is refunded to the
named rent collector.

> Controlled accounts only via this method. An autonomous account removes a limit
> through the `RemoveSpendingLimit` [settings transaction](/operations/settings/create)
> action.

## Program method — `remove_spending_limit_as_authority`

Signs with `payer` + `settings_authority`, then sends. (No rent payer — closing
*refunds* rent.)

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The account's settings authority; must sign. |
| `spending_limit` | #to_s | yes | — | The SpendingLimit PDA to close. |
| `rent_collector` | #to_s | yes | — | Receives the closed account's rent (does not sign). |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.remove_spending_limit_as_authority(
  payer:              authority,
  settings:           identity.settings_address,
  settings_authority: authority,
  spending_limit:     spending_limit,
  rent_collector:     authority.address
)
```

## Composer — `SquadsSmartAccountsRemoveSpendingLimitAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The settings authority; must sign. |
| `spending_limit` | #to_s | yes | — | The SpendingLimit PDA to close. |
| `rent_collector` | #to_s | yes | — | Receives the refunded rent. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsRemoveSpendingLimitAsAuthorityComposer.new(
  settings:           identity.settings_address,
  settings_authority: authority.address,
  spending_limit:     spending_limit,
  rent_collector:     authority.address
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[94, 32, 68, 127, 251, 44, 145, 7]`
- **Encodes (`data`):** `option_string(memo)` (the accounts carry the rest)

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the settings authority. |
| `spending_limit_index` | Integer | yes | — | Index of the SpendingLimit PDA. |
| `rent_collector_index` | Integer | yes | — | Index of the rent collector. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

> Unlike the other authority instructions, this one needs **no System program**
> account.
