---
title: PDA Derivation & Fetchers
---

# PDA Derivation & Fetchers

Address derivation is the **program layer's** responsibility — composers and
instruction builders receive already-resolved addresses. These helpers live on
`Solace::Programs::SquadsSmartAccount` (each is available as both a class method and an
instance method).

## PDA derivation

Each returns `[address, bump]` (a base58 String and the bump Integer).

| Method | Arguments | Seeds | Returns |
| --- | --- | --- | --- |
| `get_settings_address` | `settings_seed:` | `["smart_account", "settings", u128(settings_seed)]` | settings PDA |
| `get_smart_account_address` | `settings_address:`, `account_index: 0` | `["smart_account", settings, "smart_account", account_index]` | vault PDA |
| `get_spending_limit_address` | `settings_address:`, `seed:` | `["smart_account", settings, "spending_limit", seed]` | SpendingLimit PDA |
| `get_transaction_address` | `settings_address:`, `transaction_index:` | `["smart_account", settings, "transaction", u64(index)]` | Transaction PDA |
| `get_proposal_address` | `settings_address:`, `transaction_index:` | `["smart_account", settings, "transaction", u64(index), "proposal"]` | Proposal PDA |

```ruby
settings_address, = program.get_settings_address(settings_seed: 1)
vault_address,    = program.get_smart_account_address(settings_address:)
proposal_address, = program.get_proposal_address(settings_address:, transaction_index: 1)
```

> The `Transaction` and `SettingsTransaction` PDAs share the same `transaction` seeds —
> only the stored account type differs. Use `get_transaction_address` for both.

## Account fetchers

Each fetches and deserializes an on-chain account into a value object (see
[Account Types](/reference/account-types)), raising if the account doesn't exist.

| Method | Arguments | Returns |
| --- | --- | --- |
| `get_program_config` | — | `ProgramConfig` |
| `get_settings` | `settings_address:` | `Settings` |
| `get_transaction` | `transaction_address:` | `Transaction` |
| `get_settings_transaction` | `transaction_address:` | `SettingsTransaction` |
| `get_proposal` | `proposal_address:` | `Proposal` |
| `get_spending_limit` | `spending_limit_address:` | `SpendingLimit` |

## `next_smart_account`

Returns the deterministic identity of the next smart account to create — derived from
the program config's running index. Persist these values, then pass the seed to
[`create_smart_account`](/operations/create-smart-account).

```ruby
identity = program.next_smart_account
identity.settings_seed         # => Integer, pass to create_smart_account
identity.settings_address      # => base58 settings PDA
identity.smart_account_address # => base58 default vault PDA (account index 0)
```

> Subject to races: if another account is created between this call and execution, the
> creation fails cleanly with `MissingAccount` — re-fetch and retry.
