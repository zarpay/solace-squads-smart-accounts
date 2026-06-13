---
title: The Async Transaction Lifecycle
---

# The Async Transaction Lifecycle

Spending from a vault — or reconfiguring an autonomous account — goes through a
propose → vote → execute flow backed by two on-chain accounts: a **Transaction** (the
stored instructions) and a **Proposal** (the vote record). Both are derived from the
same `transaction_index`, so they are 1:1.

## The steps

1. **[Create a transaction](/operations/vault/create-transaction)** — store the inner
   instructions. Requires `Initiate`. Stored at `settings.transaction_index + 1`.
2. **[Create a proposal](/operations/vault/create-proposal)** — open voting. Requires
   `Initiate`. Starts **Active** (or **Draft** if `draft: true`, which then needs
   [activation](/operations/vault/activate-proposal)).
3. **Vote** — [approve](/operations/vault/approve-proposal),
   [reject](/operations/vault/reject-proposal), or (once approved)
   [cancel](/operations/vault/cancel-proposal). Requires `Vote`. The tally against the
   [threshold and cutoff](/concepts/permissions-and-threshold) decides the outcome.
4. **[Execute](/operations/vault/execute-transaction)** — run the instructions once the
   proposal is **Approved** and the time lock has elapsed. Requires `Execute`. The
   program signs the inner instructions as the vault PDA via CPI.
5. **[Close](/operations/vault/close-transaction)** — reclaim the accounts' rent once
   the proposal reaches a terminal state.

[Settings transactions](/operations/settings/create) follow the same flow; only the
payload differs (a batch of `SettingsAction`s applied to the account itself).

## Proposal states

| State | Meaning |
| --- | --- |
| **Draft** | Created with `draft: true`; must be activated before voting. |
| **Active** | Open for voting. |
| **Approved** | Reached the threshold; awaiting execution (and the time lock). |
| **Rejected** | Reached the rejection cutoff; terminal. |
| **Cancelled** | An Approved proposal was cancelled; terminal. |
| **Executed** | The transaction ran; terminal. |

## Time lock

If the account has a non-zero `time_lock`, an Approved proposal cannot execute until
that many seconds have passed since approval — a cooling-off window. Set it at creation
or via [`set_time_lock_as_authority`](/operations/authority/set-time-lock) /
the `SetTimeLock` settings action.

## Staleness

Changing the signer set, threshold, or time lock bumps the account's
`stale_transaction_index`, **invalidating in-flight proposals** created before the
change — they can no longer be approved. One asymmetry to know: a *vault* proposal that
was already **Approved** before going stale can still execute (the decision stands),
whereas a stale *settings* proposal cannot.
