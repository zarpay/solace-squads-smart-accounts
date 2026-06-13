---
title: Use a Spending Limit
---

# Use a Spending Limit

Transfers from a vault against an existing [spending limit](/concepts/spending-limits),
signed by one of the limit's allowed signers — **no proposal or threshold** is
involved. Works for SOL and for SPL Token / Token-2022 mints.

> The amount draws down the limit's remaining allowance for the current period
> (`SpendingLimitExceeded` if it would overspend). For token limits, the destination's
> associated token account (ATA) must already exist.

## Program method — `use_spending_limit`

Signs with `payer` + `signer`, then sends. For token limits, pass `mint` and
`token_program`; the vault and destination ATAs are derived for you. Omit them for SOL.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An allowed signer of the limit; must sign. |
| `spending_limit` | #to_s | yes | — | The SpendingLimit PDA to spend against. |
| `smart_account` | #to_s | yes | — | The vault to transfer from. |
| `destination` | #to_s | yes | — | Recipient (receives SOL, or owns the destination ATA). |
| `amount` | Integer | yes | — | Amount to transfer, in the mint's base units. |
| `decimals` | Integer | no | `9` | Mint decimals (9 for SOL). |
| `mint` | #to_s | no | `nil` | Token mint; omit for SOL. |
| `token_program` | #to_s | no | `nil` | Program owning the mint; required with `mint`. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
# SOL spend
program.use_spending_limit(
  payer:          member,
  settings:       identity.settings_address,
  signer:         member,
  spending_limit: spending_limit,
  smart_account:  identity.smart_account_address,
  destination:    recipient.address,
  amount:         100_000_000 # 0.1 SOL
)
```

## Composer — `SquadsSmartAccountsUseSpendingLimitComposer`

The composer does not derive ATAs — for token limits pass all four token accounts
explicitly. For SOL, omit them.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `signer` | #to_s · Keypair | yes | — | An allowed signer; must sign. |
| `spending_limit` | #to_s | yes | — | The SpendingLimit PDA. |
| `smart_account` | #to_s | yes | — | The vault to transfer from. |
| `destination` | #to_s | yes | — | Recipient owner. |
| `amount` | Integer | yes | — | Amount (mint base units). |
| `decimals` | Integer | no | `9` | Mint decimals. |
| `memo` | String | no | `nil` | Indexing memo. |
| `mint` | #to_s | no* | `nil` | Token mint (omit for SOL). |
| `token_program` | #to_s | no* | `nil` | Program owning the mint. |
| `smart_account_token_account` | #to_s | no* | `nil` | The vault's ATA for the mint. |
| `destination_token_account` | #to_s | no* | `nil` | The destination owner's ATA (must exist). |

\* The four token fields are required **together** for token limits; all omitted for SOL.

```ruby
composer = Solace::Composers::SquadsSmartAccountsUseSpendingLimitComposer.new(
  settings:       identity.settings_address,
  signer:         member.address,
  spending_limit: spending_limit,
  smart_account:  identity.smart_account_address,
  destination:    recipient.address,
  amount:         100_000_000
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(member)
                                .compose_transaction

tx.sign(member)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[41, 179, 70, 5, 194, 147, 239, 158]`
- **Encodes (`data`):** `le_u64(amount)` + `decimals` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `amount` | Integer | yes | — | Amount to transfer. |
| `decimals` | Integer | yes | — | Mint decimals. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `signer_index` | Integer | yes | — | Index of the allowed signer. |
| `spending_limit_index` | Integer | yes | — | Index of the SpendingLimit PDA. |
| `smart_account_index` | Integer | yes | — | Index of the vault. |
| `destination_index` | Integer | yes | — | Index of the destination. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `mint_index` | Integer | yes | — | Index of the mint (program id when SOL). |
| `smart_account_token_account_index` | Integer | yes | — | Index of the vault ATA (program id when SOL). |
| `destination_token_account_index` | Integer | yes | — | Index of the destination ATA (program id when SOL). |
| `token_program_index` | Integer | yes | — | Index of the token program (program id when SOL). |
| `program_index` | Integer | yes | — | Index of the Squads program. |

> For SOL spends, the four token-account slots are filled with the Squads program id —
> Anchor's convention for an absent optional account.
