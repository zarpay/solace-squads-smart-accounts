# solace-squads-smart-accounts

Extension gem for [`solace`](https://github.com/sebscholl/solace) that adds support for the [Squads Smart Account](https://squads.so/) program on Solana (`SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG`).

📖 **Documentation:** https://zarpay.github.io/solace-squads-smart-accounts

This repository is laid out with the gem in [`gem/`](gem/) and the documentation site in [`site/`](site/).

## Smart accounts vs. the Settings account

The naming can be confusing: `createSmartAccount` does not create an account called "smart account". It creates a **Settings** account, and the smart account exists implicitly.

- **Settings** is the control plane. It stores the governance state — signers and their permission masks, threshold, time lock, transaction index. It is the only account the instruction physically creates, because it is the only one that stores data.
- **The smart account** is the wallet — the address that holds SOL and tokens. It is a dataless PDA derived *from* the settings account:

  ```
  seeds = ["smart_account", settings_address, "smart_account", account_index]
  ```

  A dataless PDA needs no creation instruction: it exists the moment it is funded, and the program can sign as it via CPI using those seeds. Its address is implied by the settings account's existence.

One settings account governs arbitrarily many smart accounts (account index 0, 1, 2, …) — same signers and threshold, separate balances. Spending from a smart account goes through governance: a `Transaction` account holds the instructions, a `Proposal` collects votes per the settings threshold, and on execution the program signs the instructions as the smart account PDA.

## Coverage

Covers the flows needed for normal smart-account usage. See [`INSTRUCTIONS.md`](INSTRUCTIONS.md) for the per-instruction checklist.

- **Account creation** — `createSmartAccount`.
- **Async transaction lifecycle** — `createTransaction` → `createProposal` → `activateProposal` → `approveProposal` / `rejectProposal` / `cancelProposal` → `executeTransaction` → `closeTransaction`.
- **Synchronous execution** — `executeTransactionSync`: a single transaction, co-signed up to the threshold, with no proposal lifecycle.
- **Settings transactions** — both the async flow (`createSettingsTransaction` → proposal/vote → `executeSettingsTransaction` → `closeSettingsTransaction`) and the synchronous `executeSettingsTransactionSync`; all `SettingsAction` variants except `SetArchivalAuthority`.
- **Controlled-account authority actions** — add/remove signer, change threshold, set time lock, and set a new settings authority (the `*AsAuthority` instructions).
- **Spending limits** — add, remove, and use, across SOL, SPL Token, and Token-2022, in both controlled and autonomous modes.

## Limitations

- **Address Lookup Tables (ALTs) are not supported.** `createTransaction` and `executeTransaction` handle only "simple" compiled messages — the message's `address_table_lookups` must be empty, and stored-message replay on execution assumes no lookup-table accounts. Pass full 32-byte addresses in the inner instructions.
- **Ephemeral signers are not supported.** `createTransaction` is fixed at `ephemeral_signers: 0`; messages that need program-derived ephemeral signers are not handled.
- **Transaction buffers** (`createTransactionBuffer` and friends) are not implemented, so transactions too large for a single message cannot be staged.
- **Batches** (`createBatch` and friends) are not implemented.
- **`setArchivalAuthorityAsAuthority`** is deliberately skipped — the archival feature is inert in the deployed program (the field is preset to defaults and consumed by nothing). Revisit when Squads ships archival.
- **Program-config admin instructions** (`initializeProgramConfig`, `setProgramConfig*`) and **`logEvent`** are out of scope for normal usage.

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

All gem commands run from the `gem/` directory:

```sh
cd gem
bundle install
bundle exec rake        # run all tests (starts a fresh validator, funds fixtures, stops it after)
bundle exec rubocop     # lint
bundle exec rake idl:compare   # diff the local Anchor IDL against upstream
```

Tests run against a local `solana-test-validator` started with a fresh ledger every run, with the Squads program cloned from mainnet-beta. Fixture accounts are funded automatically at suite start. See `gem/CLAUDE.md` for architecture and contribution conventions.

The documentation site is a [VitePress](https://vitepress.dev/) app in `site/`:

```sh
cd site
npm install
npm run dev     # local preview
npm run build   # static build
```
