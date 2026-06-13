---
title: Permissions & Threshold
---

# Permissions & Threshold

Each member of a smart account holds a **permission mask** — any combination of three
independent bits — and the account has a **threshold** that governs voting.

## The three permissions

`Solace::SquadsSmartAccounts::Permissions` defines the bits:

| Constant | Bit | Grants the ability to… |
| --- | --- | --- |
| `INITIATE` | `0b001` | Create a transaction and open its proposal. |
| `VOTE` | `0b010` | Approve, reject, or cancel a proposal. |
| `EXECUTE` | `0b100` | Execute an approved transaction. |
| `ALL` | `0b111` | All three. |

Build a mask from the constants or with `Permissions.mask`:

```ruby
Solace::SquadsSmartAccounts::Permissions::ALL
Solace::SquadsSmartAccounts::Permissions::INITIATE | Solace::SquadsSmartAccounts::Permissions::VOTE
Solace::SquadsSmartAccounts::Permissions.mask(:vote, :execute)
```

A member is a [`SmartAccountSigner`](/reference/account-types) — a pubkey plus a mask:

```ruby
Solace::SquadsSmartAccounts::SmartAccountSigner.new(
  pubkey:     member.address,
  permission: Solace::SquadsSmartAccounts::Permissions::VOTE
)
```

Permissions can be split across members — see the separation-of-duties pattern (one
member initiates, another votes, another executes).

## Invariants

The program enforces that every account always has **at least one** member with each of
Initiate, Vote, and Execute. The threshold must be `1 ≤ threshold ≤ num_voters`, where
`num_voters` is the number of members holding the Vote permission.

## The vote math

A proposal's outcome is decided by counting Vote-holders' votes against two cutoffs:

- **Approved** when `approved.length >= threshold`.
- **Rejected** when `rejected.length >= cutoff`, where **`cutoff = num_voters − threshold + 1`**.
- **Cancelled** when `cancelled.length >= threshold` (cancellation applies to an already-Approved proposal).

A member can switch their vote: approving removes a prior rejection and vice-versa.

**Worked examples:**

| Configuration | `num_voters` | threshold | cutoff (to reject) |
| --- | --- | --- | --- |
| 1-of-1 | 1 | 1 | 1 |
| 2-of-3 | 3 | 2 | 2 |
| 3-of-3 | 3 | 3 | 1 |

In a 3-of-3, `cutoff` is 1 — a single rejection vetoes the proposal. In a 2-of-3, it
takes two approvals to pass or two rejections to kill it, leaving room to switch votes.

See the [async lifecycle](/concepts/async-transaction-lifecycle) for how these states
drive execution.
