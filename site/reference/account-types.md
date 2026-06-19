---
title: Account Types
---

# Account Types

The deserialized account state and value objects, all under
`Solace::SquadsSmartAccounts`. The account types are immutable `Data` objects returned
by the [fetchers](/reference/pda-and-fetchers).

## `Settings`

The control plane, from `get_settings`.

| Field | Type | Description |
| --- | --- | --- |
| `seed` | Integer | Index seed the settings PDA was derived from. |
| `settings_authority` | String | Reconfiguration authority; the default pubkey for autonomous accounts. |
| `threshold` | Integer | Approvals required to execute a transaction. |
| `time_lock` | Integer | Seconds between approval and execution. |
| `transaction_index` | Integer | Last transaction index (0 = none created). |
| `stale_transaction_index` | Integer | Transactions up to this index are stale. |
| `archival_authority` | String, nil | Reserved for the archival feature. |
| `archivable_after` | Integer | Reserved for the archival feature. |
| `bump` | Integer | Settings PDA bump seed. |
| `signers` | Array\<SmartAccountSigner\> | Members, sorted by pubkey on-chain. |
| `account_utilization` | Integer | Number of sub-accounts in use. |

## `SmartAccountIdentity`

From `next_smart_account` — the identity of an account to create.

| Field | Type | Description |
| --- | --- | --- |
| `settings_seed` | Integer | Seed the settings PDA is derived from. |
| `settings_address` | String | Base58 address of the settings account. |
| `smart_account_address` | String | Base58 address of the default vault (account index 0). |

## `Proposal`

The vote record, from `get_proposal`.

| Field | Type | Description |
| --- | --- | --- |
| `settings` | String | The settings account this belongs to. |
| `transaction_index` | Integer | Index of the associated transaction. |
| `rent_collector` | String | Base58 rent collector. |
| `status` | Symbol | `:draft`, `:active`, `:rejected`, `:approved`, `:executing`, `:executed`, or `:cancelled`. |
| `status_timestamp` | Integer, nil | Unix timestamp of the status change (`nil` for `:executing`). |
| `bump` | Integer | Proposal PDA bump seed. |
| `approved` | Array\<String\> | Pubkeys that approved. |
| `rejected` | Array\<String\> | Pubkeys that rejected. |
| `cancelled` | Array\<String\> | Pubkeys that cancelled. |

## `Transaction`

A stored vault transaction, from `get_transaction`.

| Field | Type | Description |
| --- | --- | --- |
| `settings` | String | The settings account this belongs to. |
| `creator` | String | Base58 creator. |
| `rent_collector` | String | Base58 rent collector. |
| `index` | Integer | Transaction index. |
| `account_index` | Integer | Vault index the message spends from. |
| `num_signers` | Integer | Message header: total signer keys. |
| `num_writable_signers` | Integer | Message header: writable signers. |
| `num_writable_non_signers` | Integer | Message header: writable non-signers. |
| `account_keys` | Array\<String\> | Message keys in canonical order. |

`#account_metas` returns the keys as ordered `{ pubkey:, signer:, writable: }` hashes —
this is what [`execute_transaction`](/operations/vault/execute-transaction) replays as
its remaining accounts.

## `SettingsTransaction`

A stored settings transaction, from `get_settings_transaction` (header only — the
actions are read on-chain at execution).

| Field | Type | Description |
| --- | --- | --- |
| `settings` | String | The settings account this belongs to. |
| `creator` | String | Base58 creator (a settings signer). |
| `rent_collector` | String | Base58 rent collector. |
| `index` | Integer | Transaction index. |
| `bump` | Integer | Transaction PDA bump seed. |

## `SpendingLimit`

From `get_spending_limit`.

| Field | Type | Description |
| --- | --- | --- |
| `settings` | String | The settings account this limit belongs to. |
| `seed` | String | Pubkey the PDA was seeded with. |
| `account_index` | Integer | Vault index the limit spends from. |
| `mint` | String | Token mint; the default pubkey means SOL. |
| `amount` | Integer | Amount spendable per period (mint base units). |
| `period` | Integer | `Period` value (reset cadence). |
| `remaining_amount` | Integer | Amount left in the current period. |
| `last_reset` | Integer | Unix timestamp of the last period reset. |
| `bump` | Integer | SpendingLimit PDA bump seed. |
| `signers` | Array\<String\> | Pubkeys allowed to use the limit. |
| `destinations` | Array\<String\> | Allowed destinations; empty = any. |
| `expiration` | Integer | Unix expiration; `I64_MAX` = never. |

## `ProgramConfig`

The global program config, from `get_program_config`.

| Field | Type | Description |
| --- | --- | --- |
| `smart_account_index` | Integer | Running count of smart accounts created. |
| `authority` | String | Pubkey that can update the config. |
| `smart_account_creation_fee` | Integer | Lamports charged per account creation. |
| `treasury` | String | Pubkey that receives creation fees. |

## Event types

These are decoded from a landed transaction's inner instructions rather than from an
account — see [`get_created_smart_account_event`](/reference/pda-and-fetchers#get-created-smart-account-event).

### `CreateSmartAccountEvent`

The event the program emits on creation, from `get_created_smart_account_event`.

| Field | Type | Description |
| --- | --- | --- |
| `new_settings_pubkey` | String | Base58 address of the settings account the program created. |

The on-chain event also carries the full new `Settings`, but only the pubkey is
decoded — derive the vault from it, or `get_settings` for the rest.

### `LogEventArgsV2`

The arguments of the program's `logEvent` self-CPI — a single Borsh-encoded
`SmartAccountEvent`. The deserialization layer the fetcher uses internally; you
rarely touch it directly.

| Field | Type | Description |
| --- | --- | --- |
| `event` | String | Borsh-encoded `SmartAccountEvent` bytes (binary string). |

## Value objects

### `SmartAccountSigner`

A member: `pubkey` (String) + `permission` (Integer mask). Build with
`SmartAccountSigner.new(pubkey:, permission:)`.

### `Permissions`

Constants `INITIATE` (`0b001`), `VOTE` (`0b010`), `EXECUTE` (`0b100`), `ALL` (`0b111`),
plus `Permissions.mask(*names)` where names are any of `:initiate`, `:vote`,
`:execute`, `:all`. See [Permissions & Threshold](/concepts/permissions-and-threshold).

### `Period`

Spending-limit reset cadence: `ONE_TIME` (`0`), `DAY` (`1`), `WEEK` (`2`), `MONTH`
(`3`). `ONE_TIME` never resets.

### `SettingsAction`

The configuration changes a [settings transaction](/operations/settings/create) applies.
Build with the factories:

| Factory | Arguments |
| --- | --- |
| `SettingsAction.add_signer` | `pubkey:`, `permission:` |
| `SettingsAction.remove_signer` | `pubkey` |
| `SettingsAction.change_threshold` | `threshold` |
| `SettingsAction.set_time_lock` | `seconds` |
| `SettingsAction.add_spending_limit` | `seed:`, `account_index:`, `mint:`, `amount:`, `period:`, `signers:`, … |
| `SettingsAction.remove_spending_limit` | `spending_limit` |
