---
title: Add a Signer
---

# Add a Signer

Adds a new member (a pubkey + [permission mask](/concepts/permissions-and-threshold))
to a **controlled** smart account — one that has a `settings_authority`. The change is
authorized by that authority's signature alone; no proposal is needed.

> Controlled accounts only. An **autonomous** account changes its membership through a
> [settings transaction](/operations/settings/create) (the `AddSigner` action) instead.
> Adding a signer grows the settings account, so a `rent_payer` funds the reallocation.

## Program method — `add_signer_as_authority`

Signs with `payer` + `settings_authority` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The account's settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the settings-account reallocation; must sign. |
| `new_signer` | SmartAccountSigner | yes | — | The member to add (pubkey + permission mask). |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.add_signer_as_authority(
  payer:              authority,
  settings:           identity.settings_address,
  settings_authority: authority,
  rent_payer:         authority,
  new_signer:         Solace::SquadsSmartAccounts::SmartAccountSigner.new(
    pubkey:     new_member.address,
    permission: Solace::SquadsSmartAccounts::Permissions::VOTE
  )
)
```

## Composer — `SquadsSmartAccountsAddSignerAsAuthorityComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `settings_authority` | #to_s · Keypair | yes | — | The settings authority; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds reallocation; must sign. |
| `new_signer` | SmartAccountSigner | yes | — | The member to add. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsAddSignerAsAuthorityComposer.new(
  settings:           identity.settings_address,
  settings_authority: authority.address,
  rent_payer:         authority.address,
  new_signer:         Solace::SquadsSmartAccounts::SmartAccountSigner.new(
    pubkey:     new_member.address,
    permission: Solace::SquadsSmartAccounts::Permissions::VOTE
  )
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(authority)
                                .compose_transaction

tx.sign(authority)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[80, 198, 228, 154, 7, 234, 99, 56]`
- **Encodes (`data`):** `pubkey(new_signer.pubkey)` + `permission byte` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `new_signer` | SmartAccountSigner | yes | — | The member to add. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `settings_authority_index` | Integer | yes | — | Index of the settings authority. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |

```ruby
ix = Solace::SquadsSmartAccounts::Instructions::AddSignerAsAuthorityInstruction.build(
  new_signer:,
  memo:                     nil,
  settings_index:           context.index_of(settings),
  settings_authority_index: context.index_of(settings_authority),
  rent_payer_index:         context.index_of(rent_payer),
  system_program_index:     context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
  program_index:            context.index_of(Solace::SquadsSmartAccounts::PROGRAM_ID)
)
```
