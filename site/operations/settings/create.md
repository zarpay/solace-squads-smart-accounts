---
title: Create a Settings Transaction
---

# Create a Settings Transaction

Stores a batch of [`SettingsAction`](/reference/account-types)s as a pending
**settings transaction** — the autonomous-account equivalent of a vault transaction,
but the thing being executed reconfigures the account itself (add/remove signers,
change threshold, set time lock, manage spending limits). It awaits a proposal and
approvals before applying.

> **Autonomous accounts only** (no settings authority). Controlled accounts reconfigure
> through the [`*AsAuthority`](/operations/authority/add-signer) instructions. The
> creator must hold the **Initiate** permission; the transaction is stored at
> `transaction_index + 1` (derived for you).

## Program method — `create_settings_transaction`

Signs with `payer` + `creator` + `rent_payer`, then sends.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the fee; co-signs. |
| `settings` | #to_s | yes | — | The settings account address. |
| `creator` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the SettingsTransaction account's rent; must sign. |
| `actions` | Array\<SettingsAction\> | yes | — | The configuration changes to store. |
| `memo` | String | no | `nil` | Optional indexing memo. |

Plus the shared `sign:` / `execute:` controls and `Solace::Transaction` return — see
[Conventions](/conventions#the-send-and-sign-trio-payer-sign-execute).

```ruby
program.create_settings_transaction(
  payer:      creator,
  settings:   identity.settings_address,
  creator:,
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

## Composer — `SquadsSmartAccountsCreateSettingsTransactionComposer`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `settings` | #to_s | yes | — | The settings account address. |
| `transaction` | #to_s | yes | — | The SettingsTransaction PDA to create (from `get_transaction_address`). |
| `creator` | #to_s · Keypair | yes | — | An Initiate-holding member; must sign. |
| `rent_payer` | #to_s · Keypair | yes | — | Funds the account's rent; must sign. |
| `actions` | Array\<SettingsAction\> | yes | — | The configuration changes to store. |
| `memo` | String | no | `nil` | Indexing memo. |

```ruby
transaction, = program.get_transaction_address(
  settings_address:  identity.settings_address,
  transaction_index: 1
)

composer = Solace::Composers::SquadsSmartAccountsCreateSettingsTransactionComposer.new(
  settings:     identity.settings_address,
  transaction:,
  creator:      creator.address,
  rent_payer:   creator.address,
  actions:      [Solace::SquadsSmartAccounts::SettingsAction.change_threshold(2)]
)

tx = Solace::TransactionComposer.new(connection:)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)
```

## Low-level instruction (advanced)

- **Discriminator:** `[101, 168, 254, 203, 222, 102, 95, 192]`
- **Encodes (`data`):** `settings_actions(actions)` + `option_string(memo)`

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `actions` | Array\<SettingsAction\> | yes | — | The configuration changes to store. |
| `memo` | String, nil | yes | — | Indexing memo, or `nil`. |
| `settings_index` | Integer | yes | — | Index of the settings account. |
| `transaction_index` | Integer | yes | — | Index of the SettingsTransaction PDA. |
| `creator_index` | Integer | yes | — | Index of the creator. |
| `rent_payer_index` | Integer | yes | — | Index of the rent payer. |
| `system_program_index` | Integer | yes | — | Index of the System program. |
| `program_index` | Integer | yes | — | Index of the Squads program. |
