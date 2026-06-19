---
title: Instruction Coverage
---

# Instruction Coverage

The Squads Smart Account program exposes 37 instructions. This library implements the
**22** needed for normal smart-account usage. `✅` = implemented (with a builder,
composer, program method, and integration tests); `✅ read-only` = decode/read
support only (for events the program emits, never client-sent); `🚫` = deliberately
skipped; `⬜` = not yet implemented.

## Core transaction lifecycle

| Instruction | Status | Docs |
| --- | --- | --- |
| `createSmartAccount` | ✅ | [Create a Smart Account](/operations/create-smart-account) |
| `createTransaction` | ✅ | [Create a Transaction](/operations/vault/create-transaction) |
| `createProposal` | ✅ | [Create a Proposal](/operations/vault/create-proposal) |
| `activateProposal` | ✅ | [Activate a Proposal](/operations/vault/activate-proposal) |
| `approveProposal` | ✅ | [Approve a Proposal](/operations/vault/approve-proposal) |
| `rejectProposal` | ✅ | [Reject a Proposal](/operations/vault/reject-proposal) |
| `cancelProposal` | ✅ | [Cancel a Proposal](/operations/vault/cancel-proposal) |
| `executeTransaction` | ✅ | [Execute a Transaction](/operations/vault/execute-transaction) |
| `closeTransaction` | ✅ | [Close a Transaction](/operations/vault/close-transaction) |
| `executeTransactionSync` | ✅ | [Execute Synchronously](/operations/execute-transaction-sync) |

## Settings transactions

| Instruction | Status | Docs |
| --- | --- | --- |
| `createSettingsTransaction` | ✅ | [Create a Settings Transaction](/operations/settings/create) |
| `executeSettingsTransaction` | ✅ | [Execute a Settings Transaction](/operations/settings/execute) |
| `closeSettingsTransaction` | ✅ | [Close a Settings Transaction](/operations/settings/close) |
| `executeSettingsTransactionSync` | ✅ | [Execute Synchronously](/operations/settings/execute-sync) |

## Authority actions (controlled accounts)

| Instruction | Status | Docs |
| --- | --- | --- |
| `addSignerAsAuthority` | ✅ | [Add a Signer](/operations/authority/add-signer) |
| `removeSignerAsAuthority` | ✅ | [Remove a Signer](/operations/authority/remove-signer) |
| `changeThresholdAsAuthority` | ✅ | [Change the Threshold](/operations/authority/change-threshold) |
| `setTimeLockAsAuthority` | ✅ | [Set the Time Lock](/operations/authority/set-time-lock) |
| `setNewSettingsAuthorityAsAuthority` | ✅ | [Set a New Settings Authority](/operations/authority/set-new-settings-authority) |
| `setArchivalAuthorityAsAuthority` | 🚫 | Skipped — the archival feature is inert in the deployed program. |

## Spending limits

| Instruction | Status | Docs |
| --- | --- | --- |
| `addSpendingLimitAsAuthority` | ✅ | [Add a Spending Limit](/operations/spending-limits/add) |
| `useSpendingLimit` | ✅ | [Use a Spending Limit](/operations/spending-limits/use) |
| `removeSpendingLimitAsAuthority` | ✅ | [Remove a Spending Limit](/operations/spending-limits/remove) |

## Events (read side)

`logEvent` is emitted by the program via self-CPI, never sent by a client, so it has
no builder/composer. Its **read** side is implemented: the event it carries is decoded
from a landed transaction's inner instructions.

| Instruction | Status | Docs |
| --- | --- | --- |
| `logEvent` → `CreateSmartAccountEvent` | ✅ read-only | [`get_created_smart_account_event`](/reference/pda-and-fetchers#get-created-smart-account-event) — resolves [windowed creation](/operations/create-smart-account#race-free-creation-with-a-window) |

## Not yet implemented

| Area | Instructions |
| --- | --- |
| Transaction buffers | `createTransactionBuffer`, `extendTransactionBuffer`, `closeTransactionBuffer`, `createTransactionFromBuffer` |
| Batches | `createBatch`, `addTransactionToBatch`, `executeBatchTransaction`, `closeBatchTransaction`, `closeBatch` |
| Program config (admin) | `initializeProgramConfig`, `setProgramConfigAuthority`, `setProgramConfigSmartAccountCreationFee`, `setProgramConfigTreasury` |

## Known limitations

- **Address Lookup Tables (ALTs)** are not supported — `createTransaction` /
  `executeTransaction` handle simple compiled messages only.
- **Ephemeral signers** are not supported (`ephemeral_signers` is fixed at 0).
