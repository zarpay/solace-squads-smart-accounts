---
title: Change the Threshold
---

# Change the Threshold

Changes how many approvals a proposal needs, on a **controlled** smart account,
authorized by the settings authority's signature.

> Controlled accounts only. An autonomous account uses the `ChangeThreshold`
> [settings transaction](/operations/settings/create) action. The new threshold must be
> ≥ 1 and ≤ the number of Vote-holding signers — see
> [Permissions & Threshold](/concepts/permissions-and-threshold).

## Program method — `change_threshold_as_authority`

Signs with `payer` + `settings_authority` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The account's settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings-account reallocation; must sign. |
| `new_threshold` | Integer | yes | — | The new approval threshold. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.change_threshold_as_authority(
  payer:              authority,
  settings:           identity.settings_address,
  settings_authority: authority,
  rent_payer:         authority,
  new_threshold:      2
)
```

## Composer — `SquadsSmartAccountsChangeThresholdAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds reallocation; must sign. |
| `new_threshold` | Integer | yes | — | The new approval threshold. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsChangeThresholdAsAuthorityComposer.new(
  settings:           identity.settings_address,
  settings_authority: authority.address,
  rent_payer:         authority.address,
  new_threshold:      2
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[51, 141, 78, 133, 70, 47, 95, 124]`
- **Encodes (`data`):** `le_u16(new_threshold)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `new_threshold` | Integer | yes | — | The new approval threshold. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the settings authority. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

```ruby
ix = Solace::SquadsSmartAccounts::Instructions::ChangeThresholdAsAuthorityInstruction.build(
  new_threshold:            2,
  memo:                     nil,
  settings_index:           context.index_of(settings),
  settings_authority_index: context.index_of(settings_authority),
  rent_payer_index:         context.index_of(rent_payer),
  system_program_index:     context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
  program_index:            context.index_of(Solace::SquadsSmartAccounts::PROGRAM_ID)
)
```
