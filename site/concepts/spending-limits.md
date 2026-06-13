---
title: Spending Limits
---

# Spending Limits

A spending limit is a pre-authorized, periodically resetting allowance that named
signers can spend from a vault **without** going through the
[proposal lifecycle](/concepts/async-transaction-lifecycle). It's how you delegate
bounded, routine spending while keeping larger movements under full multi-signer
governance.

## How it works

A `SpendingLimit` is its own account, derived from a client-chosen `seed` pubkey
(derive the address with [`get_spending_limit_address`](/reference/pda-and-fetchers)).
It records:

- **amount** — how much may be spent per period (in the mint's base units).
- **period** — the reset cadence: `ONE_TIME`, `DAY`, `WEEK`, or `MONTH` (the
  [`Period`](/reference/account-types) values). When a period elapses the remaining
  amount resets — except `ONE_TIME`, which never resets.
- **signers** — the pubkeys allowed to spend against it.
- **destinations** — allowed recipients; an empty list means any destination.
- **mint** — SOL (the default pubkey) or an SPL Token / Token-2022 mint.
- **expiration** — a Unix timestamp after which it can't be used (the default never
  expires).

## Lifecycle

- [Add a limit](/operations/spending-limits/add) — on a controlled account via the
  authority, or on an autonomous account via the `AddSpendingLimit` settings action.
- [Use a limit](/operations/spending-limits/use) — an allowed signer transfers within
  the remaining allowance. Overspending fails with `SpendingLimitExceeded`. Token
  transfers require the destination's associated token account to already exist.
- [Remove a limit](/operations/spending-limits/remove) — closes the account and
  refunds its rent.

## Tokens

`use` handles SOL (a system transfer) and SPL Token / Token-2022 mints (a
`transfer_checked` through the token interface). For token limits the vault and
destination associated token accounts (ATAs) are derived in the program layer from the
mint and owners; the destination ATA must pre-exist.
