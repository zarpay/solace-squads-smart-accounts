---
title: Add a Spending Limit
---

# Add a Spending Limit

Creates a [spending limit](/concepts/spending-limits): a pre-authorized, periodically
resetting allowance that named signers can spend from a vault **without** a proposal.
On a **controlled** account it is authorized by the settings authority.

> Controlled accounts only via this method. An autonomous account adds a limit through
> the `AddSpendingLimit` [settings transaction](/operations/settings/create) action.
> The SpendingLimit lives at its own PDA, derived from a client-chosen `seed` pubkey —
> derive it with [`get_spending_limit_address`](/reference/pda-and-fetchers).

## Program method — `add_spending_limit_as_authority`

Signs with `payer` + `settings_authority` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The account's settings authority; must sign. |
| `spending_limit` | #to_s | yes | — | The SpendingLimit PDA to create (from `get_spending_limit_address`). |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the new account's rent; must sign. |
| `seed` | #to_s | yes | — | The pubkey the SpendingLimit PDA was derived with. |
| `amount` | Integer | yes | — | Amount spendable per period, in the mint's base units. |
| `period` | Integer | yes | — | Reset cadence — a [`Period`](/reference/account-types) value. |
| `signers` | Array\<#to_s\> | yes | — | Pubkeys allowed to use the limit. |
| `account_index` | Integer | no | `0` | Vault index the limit spends from. |
| `mint` | #to_s | no | `DEFAULT_PUBKEY` | Token mint; the default pubkey means SOL. |
| `destinations` | Array\<#to_s\> | no | `[]` | Allowed destinations; empty means any. |
| `expiration` | Integer | no | `I64_MAX` | Unix expiration; the default never expires. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
seed = Solace::Keypair.generate

spending_limit, = program.get_spending_limit_address(
  settings_address: identity.settings_address,
  seed:
)

program.add_spending_limit_as_authority(
  payer:              authority,
  settings:           identity.settings_address,
  settings_authority: authority,
  rent_payer:         authority,
  spending_limit:,
  seed:,
  amount:             500_000_000, # 0.5 SOL per period
  period:             Solace::SquadsSmartAccounts::Period::DAY,
  signers:            [member.address]
)
```

## Composer — `SquadsSmartAccountsAddSpendingLimitAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The settings authority; must sign. |
| `spending_limit` | #to_s | yes | — | The SpendingLimit PDA to create. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the new account's rent; must sign. |
| `seed` | #to_s | yes | — | The pubkey the PDA was derived with. |
| `amount` | Integer | yes | — | Amount per period (mint base units). |
| `period` | Integer | yes | — | `Period` value. |
| `signers` | Array\<#to_s\> | yes | — | Pubkeys allowed to use the limit. |
| `account_index` | Integer | no | `0` | Vault index. |
| `mint` | #to_s | no | `DEFAULT_PUBKEY` | Token mint (default = SOL). |
| `destinations` | Array\<#to_s\> | no | `[]` | Allowed destinations; empty = any. |
| `expiration` | Integer | no | `I64_MAX` | Unix expiration (default = never). |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsAddSpendingLimitAsAuthorityComposer.new(
  settings:           identity.settings_address,
  settings_authority: authority.address,
  spending_limit:     spending_limit,
  rent_payer:         authority.address,
  seed:               seed.address,
  amount:             500_000_000,
  period:             Solace::SquadsSmartAccounts::Period::DAY,
  signers:            [member.address]
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[169, 189, 84, 54, 30, 244, 223, 212]`
- **Encodes (`data`):** `pubkey(seed)` + `account_index` + `pubkey(mint)` + `le_u64(amount)` + `period` + `vec_pubkeys(signers)` + `vec_pubkeys(destinations)` + `le_i64(expiration)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `seed` | #to_s | yes | — | Pubkey the PDA was derived with. |
| `account_index` | Integer | yes | — | Vault index. |
| `mint` | #to_s | yes | — | Token mint (default pubkey = SOL). |
| `amount` | Integer | yes | — | Amount per period. |
| `period` | Integer | yes | — | `Period` value. |
| `signers` | Array\<#to_s\> | yes | — | Allowed signers. |
| `destinations` | Array\<#to_s\> | yes | — | Allowed destinations (`[]` = any). |
| `expiration` | Integer | yes | — | Unix expiration. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the settings authority. |
| `spending_limit_index` | Integer | yes | — | Index of the SpendingLimit PDA. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
