# solace-squads-smart-accounts

Extension gem for [`solace`](https://github.com/sebscholl/solace) that adds support for the [Squads Smart Account](https://squads.so/) program on Solana (`SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG`).

## Smart accounts vs. the Settings account

The naming can be confusing: `createSmartAccount` does not create an account called "smart account". It creates a **Settings** account, and the smart account exists implicitly.

- **Settings** is the control plane. It stores the governance state — signers and their permission masks, threshold, time lock, transaction index. It is the only account the instruction physically creates, because it is the only one that stores data.
- **The smart account** is the wallet — the address that holds SOL and tokens. It is a dataless PDA derived *from* the settings account:

  ```
  seeds = ["smart_account", settings_address, "smart_account", account_index]
  ```

  A dataless PDA needs no creation instruction: it exists the moment it is funded, and the program can sign as it via CPI using those seeds. Its address is implied by the settings account's existence.

One settings account governs arbitrarily many smart accounts (account index 0, 1, 2, …) — same signers and threshold, separate balances. Spending from a smart account goes through governance: a `Transaction` account holds the instructions, a `Proposal` collects votes per the settings threshold, and on execution the program signs the instructions as the smart account PDA.

## Usage

```ruby
require 'solace/squads_smart_accounts'

connection = Solace::Connection.new

# The settings PDA is derived from the global program config's running index.
program_config = Solace::SquadsSmartAccounts::ProgramConfig.load(connection)

settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
  settings_seed: program_config.smart_account_index + 1
)

composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
  creator:   creator, # Solace::Keypair
  treasury:  program_config.treasury,
  settings:  settings_address,
  threshold: 1,
  signers:   [
    Solace::SquadsSmartAccounts::SmartAccountSigner.new(
      pubkey:     creator.address,
      permission: Solace::SquadsSmartAccounts::Permissions.mask(:initiate, :vote, :execute)
    )
  ],
  time_lock: 0
)

tx = Solace::TransactionComposer.new(connection: connection)
                                .add_instruction(composer)
                                .set_fee_payer(creator)
                                .compose_transaction

tx.sign(creator)
connection.send_transaction(tx.serialize)

# Read the created settings account back from the chain.
settings = Solace::SquadsSmartAccounts::Settings.load(connection, settings_address)
settings.threshold # => 1
```

Note: the settings seed must match `program_config.smart_account_index + 1` at execution time. If another creation lands first, the transaction fails cleanly with a `MissingAccount` program error — re-fetch the config and retry.

## Development

```sh
bundle exec rake   # run all tests (starts a fresh validator, funds fixtures, stops it after)
rake idl:compare   # diff the local Anchor IDL against upstream
```

Tests run against a local `solana-test-validator` started with a fresh ledger every run, with the Squads program cloned from mainnet-beta. Fixture accounts are funded automatically at suite start. See `CLAUDE.md` for architecture and contribution conventions.
