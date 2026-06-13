# Instruction Implementation Checklist

Tracks coverage of the 37 instructions in the Squads Smart Account program IDL.
Each instruction is complete when it has an instruction builder, a composer, and
integration tests verifying on-chain effects against the local validator.
Instructions marked “+ program method” also have a high-level send-and-sign
method on `Solace::Programs::SquadsSmartAccount`.

## Core Transaction Lifecycle

- [x] `createSmartAccount` — Create a smart account (+ program method `create_smart_account`)
- [x] `createTransaction` — Create a new vault transaction (+ program method `create_transaction`; simple messages only — no ephemeral signers / ALTs. NOTE: deployed program uses the newer enum args + 6th `program` account, not the stale bundled IDL)
- [x] `createProposal` — Create a new proposal (+ program method `create_proposal`)
- [x] `activateProposal` — Update proposal status from Draft to Active (+ program method `activate_proposal`; the lone proposal instruction with NO trailing `program` account)
- [x] `approveProposal` — Approve a proposal on behalf of a signer (+ program method `approve_proposal`)
- [x] `rejectProposal` — Reject a proposal on behalf of a signer (+ program method `reject_proposal`)
- [x] `cancelProposal` — Cancel a proposal on behalf of a signer (+ program method `cancel_proposal`; requires the proposal be Approved; systemProgram present for the proposal realloc, unlike approve/reject)
- [x] `executeTransaction` — Execute a smart account transaction (+ program method `execute_transaction`; replays the stored message's account metas as remaining accounts; simple messages only — no ephemeral signers / ALTs)
- [x] `executeTransactionSync` — Synchronously execute a transaction (+ program method `execute_transaction_sync`)

## Settings Transactions (autonomous accounts)

- [x] `createSettingsTransaction` — Create a settings transaction (+ program method `create_settings_transaction`; autonomous accounts only; flat args `{ actions, memo }`; shares the Transaction PDA seeds)
- [x] `closeSettingsTransaction` — Close a settings transaction and its proposal (+ program method `close_settings_transaction`; no consensus signer; closeable when the proposal is terminal or stale; rent collectors default to the on-chain stored values)
- [x] `executeSettingsTransaction` — Execute a settings transaction (+ program method `execute_settings_transaction`; no args — actions read on-chain; always passes rent_payer + systemProgram for realloc safety; spending-limit actions append SpendingLimit PDAs as remaining accounts)
- [x] `executeSettingsTransactionSync` — Synchronously execute a settings transaction (+ program method `execute_settings_transaction_sync`; all SettingsAction variants except SetArchivalAuthority, which is skipped with the archival feature)

## Authority Actions (controlled accounts)

- [x] `addSignerAsAuthority` — Add a signer (+ program method `add_signer_as_authority`)
- [x] `removeSignerAsAuthority` — Remove a signer (+ program method `remove_signer_as_authority`)
- [x] `changeThresholdAsAuthority` — Change the threshold (+ program method `change_threshold_as_authority`)
- [x] `setTimeLockAsAuthority` — Set the time lock (+ program method `set_time_lock_as_authority`)
- [x] `setNewSettingsAuthorityAsAuthority` — Change the settings authority (+ program method `set_new_settings_authority_as_authority`)
- [ ] `setArchivalAuthorityAsAuthority` — Set the archival authority — **deliberately skipped**:
      the archival feature is not implemented in the deployed program. Both the
      `createSmartAccount` handler and the `Settings` state preset
      `archival_authority` to `Pubkey::default()` and `archivable_after` to `0`
      "until the archival feature is implemented" (per program source comments),
      so this instruction mutates a field nothing consumes. Revisit when Squads
      ships archival.

## Spending Limits

Fully supported for SOL, SPL Token, and Token-2022 across both account modes:
controlled accounts manage limits via the *AsAuthority instructions; autonomous
accounts via AddSpendingLimit/RemoveSpendingLimit SettingsActions through
`executeSettingsTransactionSync`. `useSpendingLimit` handles SOL (system transfer)
and token mints (transfer_checked via the token interface) — token spends derive
the vault/destination ATAs in the program layer and require the destination ATA
to pre-exist. The bootstrap creates `spl-mint` and `token-2022-mint` fixtures
(authority `mint-authority`) for token tests.

- [x] `addSpendingLimitAsAuthority` — Create a spending limit (+ program method `add_spending_limit_as_authority`)
- [x] `removeSpendingLimitAsAuthority` — Remove a spending limit (+ program method `remove_spending_limit_as_authority`)
- [x] `useSpendingLimit` — Transfer from a vault via a spending limit (+ program method `use_spending_limit`; SOL, SPL Token, and Token-2022)

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
- [x] `get_transaction_address` / `get_proposal_address` — async lifecycle PDA derivation
- [x] `get_transaction` / `get_proposal` — fetch + deserialize async lifecycle state (`Transaction#account_metas` reconstructs execute remaining accounts)
- [x] `get_settings_transaction` — fetch + deserialize a SettingsTransaction (header only; resolves rent collector for close)
