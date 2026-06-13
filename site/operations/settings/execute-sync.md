---
title: Execute a Settings Transaction Synchronously
---

# Execute a Settings Transaction Synchronously

Applies a batch of [`SettingsAction`](/reference/account-types)s to an **autonomous**
account in a single transaction — no stored transaction, proposal, or voting lifecycle.
The outer transaction must simply carry enough co-signatures to reach the
[threshold](/concepts/permissions-and-threshold).

> Autonomous accounts only — controlled accounts are rejected (use the
> [`*AsAuthority`](/operations/authority/add-signer) instructions). Pass exactly enough
> `signers` to meet the threshold; each must be a `Keypair` so it can sign.

## Program method — `execute_settings_transaction_sync`

Signs with `payer` + each of `signers` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `signers` | Array\<#to_s · Keypair\> | yes | — | Co-signers proving threshold consensus; must sign. |
| `actions` | Array\<SettingsAction\> | yes | — | Actions applied atomically. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds any settings reallocation; must sign. |
| `spending_limit_accounts` | Array\<#to_s\> | no | `[]` | SpendingLimit PDAs touched by the actions, in action order. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.execute_settings_transaction_sync(
  payer:      creator,
  settings:   identity.settings_address,
  signers:    [creator],
  rent_payer: creator,
  actions:    [
    Solace::SquadsSmartAccounts::SettingsAction.add_signer(
      pubkey:     new_member.address,
      permission: Solace::SquadsSmartAccounts::Permissions::ALL
    ),
    Solace::SquadsSmartAccounts::SettingsAction.change_threshold(2)
  ]
)
```

## Composer — `SquadsSmartAccountsExecuteSettingsTransactionSyncComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `signers` | Array\<#to_s · Keypair\> | yes | — | Co-signers proving threshold consensus. |
| `actions` | Array\<SettingsAction\> | yes | — | Actions applied atomically. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds reallocation; must sign. |
| `spending_limit_accounts` | Array\<#to_s\> | no | `[]` | SpendingLimit PDAs touched by the actions, in action order. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
composer = Solace::Composers::SquadsSmartAccountsExecuteSettingsTransactionSyncComposer.new(
  settings:   identity.settings_address,
  signers:    [creator.address],
  rent_payer: creator.address,
  actions:    [Solace::SquadsSmartAccounts::SettingsAction.change_threshold(2)]
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[138, 209, 64, 163, 79, 67, 233, 76]`
- **Encodes (`data`):** `num_signers` + `settings_actions(actions)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `num_signers` | Integer | yes | — | Number of co-signers proving threshold consensus. |
| `actions` | Array\<SettingsAction\> | yes | — | Actions applied atomically. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
| `signer_indices` | Array\<Integer\> | yes | — | Indices of the co-signers (the leading remaining accounts). |
| `spending_limit_indices` | Array\<Integer\> | no | `[]` | Indices of SpendingLimit PDAs, in action order. |
