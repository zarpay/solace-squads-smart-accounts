---
title: Set the Time Lock
---

# Set the Time Lock

Sets the cooling-off period (in seconds) between a proposal's approval and when it may
execute, on a **controlled** smart account, authorized by the settings authority.

> Controlled accounts only. An autonomous account uses the `SetTimeLock`
> [settings transaction](/operations/settings/create) action. See
> [The Async Transaction Lifecycle](/concepts/async-transaction-lifecycle) for how the
> time lock gates execution.

## Program method — `set_time_lock_as_authority`

Signs with `payer` + `settings_authority` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The account's settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings-account reallocation; must sign. |
| `time_lock` | Integer | yes | — | Seconds between approval and execution (`0` to disable). |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.set_time_lock_as_authority(
  payer:              authority,
  settings:           identity.settings_address,
  settings_authority: authority,
  rent_payer:         authority,
  time_lock:          3600 # one hour
)
```

## Composer — `SquadsSmartAccountsSetTimeLockAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds reallocation; must sign. |
| `time_lock` | Integer | yes | — | Seconds between approval and execution. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsSetTimeLockAsAuthorityComposer.new(
  settings:           identity.settings_address,
  settings_authority: authority.address,
  rent_payer:         authority.address,
  time_lock:          3600
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[2, 234, 93, 93, 40, 92, 31, 234]`
- **Encodes (`data`):** `le_u32(time_lock)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `time_lock` | Integer | yes | — | Seconds between approval and execution. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the settings authority. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

```ruby
ix = Solace::SquadsSmartAccounts::Instructions::SetTimeLockAsAuthorityInstruction.build(
  time_lock:                3600,
  memo:                     nil,
  settings_index:           context.index_of(settings),
  settings_authority_index: context.index_of(settings_authority),
  rent_payer_index:         context.index_of(rent_payer),
  system_program_index:     context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
  program_index:            context.index_of(Solace::SquadsSmartAccounts::PROGRAM_ID)
)
```
