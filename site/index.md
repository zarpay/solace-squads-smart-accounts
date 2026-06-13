---
layout: home
hero:
  name: Squads Smart Accounts
  text: Multi-signer smart accounts on Solana, in Ruby
  tagline: A Solace extension for the Squads Smart Account program — create smart accounts, run the full propose → vote → execute lifecycle, and manage settings and spending limits from idiomatic Ruby.
  actions:
    - theme: brand
      text: Quick Start
      link: /getting-started/
    - theme: alt
      text: Conventions
      link: /conventions
---

## Relationship to Solace

This is an extension gem for [`solace`](https://github.com/sebscholl/solace), the Ruby
toolkit for Solana. Solace provides four layered abstractions; this gem adds the
Squads Smart Account program (`SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG`) to the
middle two and ships a high-level client on top:

| Layer | Provided by | This gem adds |
| --- | --- | --- |
| Primitives — `Transaction`, `Message`, `Instruction`, `AccountContext`, `Codecs` | Solace | — (reused as-is) |
| **Instruction builders** | pattern from Solace | One builder per Squads instruction |
| **Composers** | `Solace::Composers::Base` | One composer per instruction |
| Program clients — `Solace::Programs::Base` | pattern from Solace | `Solace::Programs::SquadsSmartAccount` (PDA derivation + send-and-sign) |

In short: you work in Ruby with `Solace::Keypair`, `Solace::Connection`, and the
`SquadsSmartAccount` client; this gem handles the Squads-specific encoding, account
derivation, and the smart-account governance lifecycle. See [Conventions](/conventions) for
how the three layers fit together.

## What's implemented

Everything needed for normal smart-account usage — **22 of the program's 37
instructions**. Each links to its operation page.

**Account**
- [Create a smart account](/operations/create-smart-account)

**Vault transaction lifecycle** — move funds out of a vault through governance
- [Create a transaction](/operations/vault/create-transaction) → [create a proposal](/operations/vault/create-proposal) → [activate](/operations/vault/activate-proposal) → [approve](/operations/vault/approve-proposal) / [reject](/operations/vault/reject-proposal) / [cancel](/operations/vault/cancel-proposal) → [execute](/operations/vault/execute-transaction) → [close](/operations/vault/close-transaction)
- [Execute synchronously](/operations/execute-transaction-sync) (single transaction, no proposal)

**Settings transactions** — change the account's own configuration through governance
- [Create](/operations/settings/create) → propose/vote → [execute](/operations/settings/execute) → [close](/operations/settings/close)
- [Execute synchronously](/operations/settings/execute-sync)

**Authority actions** — for controlled accounts (a single settings authority)
- [Add a signer](/operations/authority/add-signer) · [remove a signer](/operations/authority/remove-signer) · [change the threshold](/operations/authority/change-threshold) · [set the time lock](/operations/authority/set-time-lock) · [set a new settings authority](/operations/authority/set-new-settings-authority)

**Spending limits** — pre-authorized, capped spending (SOL, SPL Token, Token-2022)
- [Add](/operations/spending-limits/add) · [use](/operations/spending-limits/use) · [remove](/operations/spending-limits/remove)

## Not yet implemented

| Area | Status |
| --- | --- |
| **Address Lookup Tables (ALTs)** | Not supported — `createTransaction` / `executeTransaction` handle simple compiled messages only. |
| **Ephemeral signers** | Not supported — `ephemeral_signers` is fixed at 0. |
| Transaction buffers (`createTransactionBuffer` and friends) | Not implemented — large transactions can't be staged. |
| Batches (`createBatch` and friends) | Not implemented. |
| `setArchivalAuthorityAsAuthority` | Deliberately skipped — the archival feature is inert in the deployed program. |
| Program-config admin (`initializeProgramConfig`, `setProgramConfig*`) and `logEvent` | Out of scope for normal usage. |

The full instruction-by-instruction matrix lives in
[Reference › Instruction Coverage](/reference/instruction-coverage).
