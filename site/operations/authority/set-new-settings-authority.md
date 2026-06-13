---
title: Set a New Settings Authority
---

# Set a New Settings Authority

Hands the reconfiguration authority of a **controlled** smart account to a new key —
or renounces it entirely, permanently converting the account to **autonomous**.

> Pass `new_settings_authority: nil` to renounce: the program stores
> `Pubkey::default()`, after which the account can only be reconfigured through
> [settings transactions](/operations/settings/create). This is irreversible.

## Program method — `set_new_settings_authority_as_authority`

Signs with `payer` + `settings_authority` (the current one) + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The **current** settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings-account reallocation; must sign. |
| `new_settings_authority` | #to_s, nil | yes | — | The new authority pubkey, or `nil` to renounce (→ autonomous). |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.set_new_settings_authority_as_authority(
  payer:                  authority,
  settings:               identity.settings_address,
  settings_authority:     authority,
  rent_payer:             authority,
  new_settings_authority: new_authority.address # or nil to renounce
)
```

## Composer — `SquadsSmartAccountsSetNewSettingsAuthorityAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The current settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds reallocation; must sign. |
| `new_settings_authority` | #to_s, nil | yes | — | New authority, or `nil` to renounce (stored as the default pubkey). |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsSetNewSettingsAuthorityAsAuthorityComposer.new(
  settings:               identity.settings_address,
  settings_authority:     authority.address,
  rent_payer:             authority.address,
  new_settings_authority: new_authority.address
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[221, 112, 133, 229, 146, 58, 90, 56]`
- **Encodes (`data`):** `pubkey(new_settings_authority)` + `option_string(memo)` (renounce ⇒ the default pubkey)

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `new_settings_authority` | #to_s | yes | — | New authority pubkey (the default pubkey to renounce). |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the current settings authority. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

```ruby
ix = Solace::SquadsSmartAccounts::Instructions::SetNewSettingsAuthorityAsAuthorityInstruction.build(
  new_settings_authority:   new_authority.address,
  memo:                     nil,
  settings_index:           context.index_of(settings),
  settings_authority_index: context.index_of(settings_authority),
  rent_payer_index:         context.index_of(rent_payer),
  system_program_index:     context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
  program_index:            context.index_of(Solace::SquadsSmartAccounts::PROGRAM_ID)
)
```
