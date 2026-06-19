# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-06-19

### Added

- **Race-free smart account creation.** `create_smart_account` and
  `compose_create_smart_account` accept a `window:` argument that offers a window of
  consecutive candidate settings PDAs as remaining accounts; the program initializes
  whichever matches the freshly incremented index, so creation succeeds even when
  other accounts are created concurrently. Defaults to `1` (the previous
  single-PDA behavior — fully backwards compatible).
- `next_smart_account_candidates` returns the candidate window for clients to persist
  and match against, and `get_created_smart_account_event` decodes the
  `CreateSmartAccountEvent` the program emits via its `logEvent` self-CPI to resolve
  which candidate was created.
- New value types `LogEventArgsV2` and `CreateSmartAccountEvent`.

## [0.1.0] - 2026-06-14

Initial release — covers 22 of the 37 Squads Smart Account program instructions, every
flow needed for normal smart-account usage.

### Added

- **Account creation** — `createSmartAccount`.
- **Async transaction lifecycle** — `createTransaction` → `createProposal` →
  `activateProposal` → `approveProposal` / `rejectProposal` / `cancelProposal` →
  `executeTransaction` → `closeTransaction`.
- **Synchronous execution** — `executeTransactionSync`.
- **Settings transactions** — async (`createSettingsTransaction` →
  `executeSettingsTransaction` → `closeSettingsTransaction`) and synchronous
  (`executeSettingsTransactionSync`); all `SettingsAction` variants except
  `SetArchivalAuthority`.
- **Controlled-account authority actions** — add/remove signer, change threshold,
  set time lock, set new settings authority (the `*AsAuthority` instructions).
- **Spending limits** — add, remove, and use across SOL, SPL Token, and Token-2022,
  in both controlled and autonomous modes.
- **Vault address lookup** — `VaultIndex.build` / `VaultIndex.lookup` recover a smart
  account's index and settings address from its vault address (the derivation is
  one-way, so a precomputed table inverts it).
- Each instruction ships with an instruction builder, a composer, and integration
  tests against a local `solana-test-validator`; consequential program methods are
  covered in both self-sponsored and sponsored fee-payer modes, alongside a suite of
  advanced governance-lifecycle integration tests (reject/re-propose, evolving
  governance, separated permissions, stale-proposal invalidation, the time lock,
  multi-instruction transactions, and SPL token movement).
- A [VitePress documentation site](https://zarpay.github.io/solace-squads-smart-accounts)
  and the standard repository layout (gem in `gem/`, docs in `site/`).

### Known limitations

- Address Lookup Tables (ALTs) and ephemeral signers are not supported.
- Transaction buffers and batches are not implemented.

[0.1.1]: https://github.com/zarpay/solace-squads-smart-accounts/releases/tag/v0.1.1
[0.1.0]: https://github.com/zarpay/solace-squads-smart-accounts/releases/tag/v0.1.0
