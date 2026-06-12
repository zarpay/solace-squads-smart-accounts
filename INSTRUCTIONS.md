# Instruction Implementation Checklist

Tracks coverage of the 37 instructions in the Squads Smart Account program IDL.
Each instruction is complete when it has an instruction builder, a composer, and
integration tests verifying on-chain effects against the local validator.
Instructions marked “+ program method” also have a high-level send-and-sign
method on `Solace::Programs::SquadsSmartAccount`.

## Core Transaction Lifecycle

- [x] `createSmartAccount` — Create a smart account (+ program method `create_smart_account`)
- [ ] `createTransaction` — Create a new vault transaction
- [ ] `createProposal` — Create a new proposal
- [ ] `activateProposal` — Update proposal status from Draft to Active
- [ ] `approveProposal` — Approve a proposal on behalf of a signer
- [ ] `rejectProposal` — Reject a proposal on behalf of a signer
- [ ] `cancelProposal` — Cancel a proposal on behalf of a signer
- [ ] `executeTransaction` — Execute a smart account transaction
- [x] `executeTransactionSync` — Synchronously execute a transaction (+ program method `execute_transaction_sync`)

## Settings Transactions (autonomous accounts)

- [ ] `createSettingsTransaction` — Create a settings transaction
- [ ] `executeSettingsTransaction` — Execute a settings transaction
- [ ] `executeSettingsTransactionSync` — Synchronously execute a settings transaction
- [ ] `closeSettingsTransaction` — Close a settings transaction and its proposal

## Authority Actions (controlled accounts)

- [x] `addSignerAsAuthority` — Add a signer (+ program method `add_signer_as_authority`)
- [x] `removeSignerAsAuthority` — Remove a signer (+ program method `remove_signer_as_authority`)
- [x] `changeThresholdAsAuthority` — Change the threshold (+ program method `change_threshold_as_authority`)
- [ ] `setTimeLockAsAuthority` — Set the time lock
- [ ] `setNewSettingsAuthorityAsAuthority` — Change the settings authority
- [ ] `setArchivalAuthorityAsAuthority` — Set the archival authority
- [ ] `addSpendingLimitAsAuthority` — Create a spending limit
- [ ] `removeSpendingLimitAsAuthority` — Remove a spending limit

## Spending Limits

- [ ] `useSpendingLimit` — Transfer tokens from a vault via a spending limit

## Transaction Buffers (large transactions)

- [ ] `createTransactionBuffer` — Create a transaction buffer account
- [ ] `extendTransactionBuffer` — Append data to a transaction buffer
- [ ] `closeTransactionBuffer` — Close a transaction buffer
- [ ] `createTransactionFromBuffer` — Create a vault transaction from a completed buffer

## Batches

- [ ] `createBatch` — Create a new batch
- [ ] `addTransactionToBatch` — Add a transaction to a batch
- [ ] `executeBatchTransaction` — Execute a transaction from a batch
- [ ] `closeBatchTransaction` — Close a batch transaction
- [ ] `closeBatch` — Close a batch and its proposal

## Account Cleanup

- [ ] `closeTransaction` — Close a transaction and its proposal

## Program Config (admin — likely out of scope)

These manage the global program config and require the hard-coded initializer /
config authority. Not needed for normal smart account usage.

- [ ] `initializeProgramConfig` — Initialize the program config
- [ ] `setProgramConfigAuthority` — Set the config authority
- [ ] `setProgramConfigSmartAccountCreationFee` — Set the creation fee
- [ ] `setProgramConfigTreasury` — Set the treasury

## Other

- [ ] `logEvent` — Log an event (used via CPI by the program itself)

## Program Layer (supporting surface, not IDL instructions)

- [x] `get_settings_address` / `get_smart_account_address` — PDA derivation
- [x] `get_program_config` / `get_settings` — fetch + deserialize account state
- [x] `next_smart_account` — full identity (seed, settings address, vault address) for client indexing
- [x] `create_smart_account` / `compose_create_smart_account` — send-and-sign creation
- [x] `execute_transaction_sync` / `compose_execute_transaction_sync` — send-and-sign vault spend
