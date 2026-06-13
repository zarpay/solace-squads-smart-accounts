# solace-squads-smart-accounts

[![CI](https://github.com/zarpay/solace-squads-smart-accounts/actions/workflows/main.yml/badge.svg)](https://github.com/zarpay/solace-squads-smart-accounts/actions/workflows/main.yml)
[![Docs](https://img.shields.io/badge/docs-zarpay.github.io-2b7489.svg)](https://zarpay.github.io/solace-squads-smart-accounts)
[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE.txt)
[![Ruby](https://img.shields.io/badge/ruby-%E2%89%A5%203.1-CC342D.svg)](https://www.ruby-lang.org/)
[![Built on Solace](https://img.shields.io/badge/built%20on-Solace-6d28d9.svg)](https://github.com/sebscholl/solace)

A Ruby toolkit for the [Squads **Smart Account**](https://squads.so/) program on Solana
(`SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG`) — create multi-signer accounts, run the
full propose → vote → execute governance lifecycle, manage settings and spending limits,
all from idiomatic Ruby. It is an extension gem for [`solace`](https://github.com/sebscholl/solace),
reusing its primitives and adding the Squads-specific instructions, composers, account
types, and a high-level program client.

> **Squads Smart Account is a distinct program from Squads Multisig.** This library
> targets the Smart Account program only.

📖 **Documentation:** **https://zarpay.github.io/solace-squads-smart-accounts**

The gem lives in [`gem/`](gem/); the documentation site (VitePress) lives in
[`site/`](site/).

## Why a "smart account"?

The naming can be confusing: `createSmartAccount` does not create an account called
"smart account". It creates a **Settings** account, and the smart account exists
implicitly.

- **Settings** is the control plane. It stores the governance state — signers and their
  permission masks, threshold, time lock, transaction index. It is the only account the
  instruction physically creates, because it is the only one that stores data.
- **The smart account** is the wallet — the address that holds SOL and tokens. It is a
  dataless PDA derived *from* the settings account:

  ```
  seeds = ["smart_account", settings_address, "smart_account", account_index]
  ```

  It needs no creation instruction: it exists the moment it is funded, and the program
  signs as it (via CPI) using those seeds.

One settings account governs arbitrarily many smart accounts (account index 0, 1, 2, …)
— same signers and threshold, separate balances. Spending from a smart account goes
through governance: a `Transaction` account holds the instructions, a `Proposal`
collects votes per the threshold, and on execution the program signs the instructions as
the smart-account PDA.

## Quick start

```ruby
require 'solace/squads_smart_accounts'

connection = Solace::Connection.new
program    = Solace::Programs::SquadsSmartAccount.new(connection:)

creator  = Solace::Keypair.generate # a funded keypair
identity = program.next_smart_account

# Create a 1-of-1 smart account.
program.create_smart_account(
  payer:         creator,
  settings_seed: identity.settings_seed,
  creator:,
  threshold:     1,
  signers:       [
    Solace::SquadsSmartAccounts::SmartAccountSigner.new(
      pubkey:     creator.address,
      permission: Solace::SquadsSmartAccounts::Permissions::ALL
    )
  ]
)

settings = program.get_settings(settings_address: identity.settings_address)
settings.threshold # => 1
```

Spending from the vault then runs through the lifecycle — `create_transaction` →
`create_proposal` → `approve_proposal` → `execute_transaction`. See the
[Quick Start guide](https://zarpay.github.io/solace-squads-smart-accounts/getting-started/)
for the full walkthrough, and the docs for a page per operation documented at the
program-method, composer, and instruction level.

## Coverage

Covers the flows needed for normal smart-account usage — **22 of the program's 37
instructions**. Full matrix:
[Instruction Coverage](https://zarpay.github.io/solace-squads-smart-accounts/reference/instruction-coverage).

- **Account creation** — `createSmartAccount`.
- **Async transaction lifecycle** — `createTransaction` → `createProposal` → `activateProposal` → `approveProposal` / `rejectProposal` / `cancelProposal` → `executeTransaction` → `closeTransaction`.
- **Synchronous execution** — `executeTransactionSync` (a single transaction, co-signed to threshold, no proposal lifecycle).
- **Settings transactions** — async (`createSettingsTransaction` → proposal/vote → `executeSettingsTransaction` → `closeSettingsTransaction`) and synchronous (`executeSettingsTransactionSync`); all `SettingsAction` variants except `SetArchivalAuthority`.
- **Controlled-account authority actions** — add/remove signer, change threshold, set time lock, set a new settings authority (the `*AsAuthority` instructions).
- **Spending limits** — add, use, and remove, across SOL, SPL Token, and Token-2022, in both controlled and autonomous modes.

## Limitations

- **Address Lookup Tables (ALTs) are not supported.** `createTransaction` and `executeTransaction` handle only "simple" compiled messages — the message's `address_table_lookups` must be empty. Pass full 32-byte addresses in the inner instructions.
- **Ephemeral signers are not supported** (`ephemeral_signers` is fixed at 0).
- **Transaction buffers** and **batches** are not implemented.
- **`setArchivalAuthorityAsAuthority`** is deliberately skipped — the archival feature is inert in the deployed program.
- **Program-config admin instructions** and **`logEvent`** are out of scope for normal usage.

## Development

The gem lives in `gem/`; run all gem commands from there:

```sh
cd gem
bundle install
bundle exec rake             # run all tests (boots a fresh solana-test-validator, funds fixtures, stops it after)
bundle exec rubocop          # lint
bundle exec rake idl:compare # diff the local Anchor IDL against upstream
```

Tests run against a local `solana-test-validator` started with a fresh ledger every
run, with the Squads program cloned from mainnet-beta; fixture accounts are funded
automatically at suite start. See [`gem/CLAUDE.md`](gem/CLAUDE.md) for architecture and
contribution conventions and [`gem/INSTRUCTIONS.md`](gem/INSTRUCTIONS.md) for the
per-instruction checklist.

The documentation site is a [VitePress](https://vitepress.dev/) app in `site/`:

```sh
cd site
npm install
npm run dev     # local preview
npm run build   # static build
```

## License

Released under the [MIT License](LICENSE.txt).
