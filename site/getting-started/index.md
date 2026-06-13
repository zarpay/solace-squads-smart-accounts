---
title: Quick Start
---

# Quick Start

This walks through the whole arc: install the gem, create a smart account, fund its
vault, and move funds out through the governance lifecycle.

## Install

Add the gem to your `Gemfile` (it pulls in `solace`):

```ruby
gem 'solace-squads-smart-accounts'
```

```sh
bundle install
```

```ruby
require 'solace/squads_smart_accounts'
```

## Create a smart account

A smart account is governed by a **Settings** account and holds funds in one or more
**vault** PDAs derived from it (see [Settings vs. Smart Account](/concepts/settings-vs-smart-account)).
Derive the next account's identity, then create it:

```ruby
connection = Solace::Connection.new
program    = Solace::Programs::SquadsSmartAccount.new(connection:)

creator = Solace::Keypair.generate # a funded keypair

# Deterministic identity of the next account: settings seed, settings address, vault address.
identity = program.next_smart_account

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
```

This is a 1-of-1 account: `creator` holds all permissions and a single approval
executes anything. See [Permissions & Threshold](/concepts/permissions-and-threshold)
for multi-signer configurations.

## Move funds through the lifecycle

Spending from a vault goes through governance: store a transaction, open a proposal,
collect approvals, then execute (see [The Async Transaction Lifecycle](/concepts/async-transaction-lifecycle)).
Fund the vault, then run the four steps:

```ruby
# Fund the vault (any transfer to the vault address works).
# identity.smart_account_address is the vault.

recipient = Solace::Keypair.generate

# 1. Store a vault → recipient transfer.
program.create_transaction(
  payer:        creator,
  settings:     identity.settings_address,
  creator:,
  rent_payer:   creator,
  instructions: [
    Solace::Composers::SystemProgramTransferComposer.new(
      from:     identity.smart_account_address,
      to:       recipient.address,
      lamports: 250_000_000
    )
  ]
)

# 2. Open a proposal for transaction index 1.
program.create_proposal(payer: creator, settings: identity.settings_address, creator:, rent_payer: creator, transaction_index: 1)

# 3. Approve it (a single approval reaches the 1-of-1 threshold).
program.approve_proposal(payer: creator, settings: identity.settings_address, signer: creator, transaction_index: 1)

# 4. Execute — the program signs the transfer as the vault PDA via CPI.
program.execute_transaction(payer: creator, settings: identity.settings_address, signer: creator, transaction_index: 1)
```

The recipient is now 0.25 SOL richer, paid out of the vault under multi-signer governance.

## Where to next

- [Conventions](/conventions) — the shared rules every method follows (the three
  layers, pubkey/keypair arguments, `payer`/`sign`/`execute`).
- [Concepts](/concepts/settings-vs-smart-account) — the mental model behind smart
  accounts, permissions, the async lifecycle, and spending limits.
- [Operations](/operations/create-smart-account) — a page per operation, documented at
  the program-method, composer, and instruction level.
