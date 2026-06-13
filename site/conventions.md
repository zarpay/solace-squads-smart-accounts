---
title: Conventions
---

# Conventions

Every operation in this library is documented the same way, and the methods share a
small set of cross-cutting rules. Read this page once; the operation pages assume it.

## The three layers

This gem is a [Solace](https://github.com/sebscholl/solace) extension, and it mirrors
Solace's layering. Each operation is available at three levels, from highest to lowest:

| Layer | What it is | Reach for it when |
| --- | --- | --- |
| **Program method** | A send-and-sign client method on `Solace::Programs::SquadsSmartAccount` (e.g. `create_smart_account`). Derives PDAs, builds the transaction, signs, and sends. | The common case — you want one call that does everything. |
| **Composer** | A `Solace::Composers::Base` subclass (e.g. `SquadsSmartAccountsCreateSmartAccountComposer`) that contributes one instruction to a transaction. | You're batching several instructions into one transaction, or you want control over the fee payer and signing. |
| **Instruction** | A stateless builder (e.g. `Instructions::CreateSmartAccountInstruction`) that encodes the raw program instruction. | You need byte-level control and are assembling the message yourself. |

Each operation page documents all three.

> Addresses (PDAs) are always resolved in the **program layer**. Composers and
> instruction builders receive already-resolved addresses — see
> [PDA Derivation & Fetchers](/reference/pda-and-fetchers).

## Pubkey arguments accept strings, public keys, or keypairs

Any argument whose type is written **`#to_s`** accepts a base58 `String`, a
`Solace::PublicKey`, or a `Solace::Keypair` — they are all normalized with `.to_s`.

An argument typed **`Keypair`** (or **`#to_s · Keypair`** where it must sign) needs an
actual `Solace::Keypair`, because the transaction requires its signature.

## The send-and-sign trio: `payer`, `sign`, `execute`

Every program method (`create_*`, `execute_*`, `approve_*`, …) takes the same three
control arguments in addition to its domain arguments:

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `payer` | Keypair | yes | — | Pays the transaction fee (and any account rent), and co-signs the transaction. |
| `sign` | Boolean | no | `true` | Sign the transaction with `payer` and the operation's required signers. |
| `execute` | Boolean | no | `true` | Submit the signed transaction to the cluster. Set `false` to build/sign without sending. |

**Returns** `Solace::Transaction` — the signed transaction, already submitted when
`execute: true`. To inspect or send it yourself, pass `execute: false` (or
`sign: false` to get an unsigned transaction).

The operation pages list each method's **domain** arguments plus `payer`; they don't
re-document `sign`/`execute`/the return value — those are always as above.

## Fee payer vs. member signer

The `payer` funds and signs the transaction; it does **not** need to be a member of the
smart account. A smart-account **member** (a signer with the right permission) co-signs
to *authorize* the action. These can be different keys:

- A member that is not the `payer` simply adds its signature — it spends no lamports.
- This is how a sponsor can pay fees for an action a member authorizes.

Which member signature each operation needs is noted on its page (and follows from the
[permissions model](/concepts/permissions-and-threshold)).

## Reusable setup

The examples throughout the docs assume this setup:

```ruby
require 'solace/squads_smart_accounts'

connection = Solace::Connection.new
program    = Solace::Programs::SquadsSmartAccount.new(connection:)

# Funded keypairs (your wallets / signers).
creator = Solace::Keypair.generate
```

`program.next_smart_account` returns the deterministic identity (settings seed,
settings address, vault address) of the next smart account to create — persist those
values, then pass the seed to `create_smart_account`.
