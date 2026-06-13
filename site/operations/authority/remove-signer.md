---
title: Remove a Signer
---

# Remove a Signer

Removes a member from a **controlled** smart account, authorized by the settings
authority's signature.

> Controlled accounts only. An autonomous account uses the `RemoveSigner`
> [settings transaction](/operations/settings/create) action instead. The threshold
> must remain valid (≤ the number of remaining Vote-holding signers).

## Program method — `remove_signer_as_authority`

Signs with `payer` + `settings_authority` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The account's settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings-account reallocation; must sign. |
| `old_signer` | #to_s | yes | — | Base58 pubkey of the member to remove. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.remove_signer_as_authority(
  payer:              authority,
  settings:           identity.settings_address,
  settings_authority: authority,
  rent_payer:         authority,
  old_signer:         member.address
)
```

## Composer — `SquadsSmartAccountsRemoveSignerAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds reallocation; must sign. |
| `old_signer` | #to_s | yes | — | Pubkey of the member to remove. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsRemoveSignerAsAuthorityComposer.new(
  settings:           identity.settings_address,
  settings_authority: authority.address,
  rent_payer:         authority.address,
  old_signer:         member.address
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[58, 19, 149, 16, 181, 16, 125, 148]`
- **Encodes (`data`):** `pubkey(old_signer)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `old_signer` | #to_s | yes | — | Pubkey of the member to remove. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the settings authority. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

```ruby
ix = Solace::SquadsSmartAccounts::Instructions::RemoveSignerAsAuthorityInstruction.build(
  old_signer:               member.address,
  memo:                     nil,
  settings_index:           context.index_of(settings),
  settings_authority_index: context.index_of(settings_authority),
  rent_payer_index:         context.index_of(rent_payer),
  system_program_index:     context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
  program_index:            context.index_of(Solace::SquadsSmartAccounts::PROGRAM_ID)
)
```
