---
title: Settings vs. Smart Account
---

# Settings vs. Smart Account

The naming trips people up: `createSmartAccount` does **not** create an account called
"smart account". It creates a **Settings** account, and the smart account exists
implicitly.

## Settings — the control plane

The Settings account stores the governance state: the signer set and their
[permission masks](/concepts/permissions-and-threshold), the threshold, the time lock,
and the running transaction index. It is the only account
[`create_smart_account`](/operations/create-smart-account) physically creates, because
it is the only one that stores data.

## The smart account — the wallet

The smart account is the address that holds SOL and tokens. It is a **dataless PDA**
derived *from* the settings account:

```
seeds = ["smart_account", settings_address, "smart_account", account_index]
```

A dataless PDA needs no creation instruction: it exists the moment it is funded, and
the program can sign as it (via CPI) using those seeds. Its address is implied by the
settings account's existence — derive it with
[`get_smart_account_address`](/reference/pda-and-fetchers).

One settings account governs arbitrarily many smart accounts — `account_index` 0, 1,
2, … — same signers and threshold, separate balances.

## Spending goes through governance

Moving funds out of a vault is not a direct transfer. It goes through the
[async lifecycle](/concepts/async-transaction-lifecycle): a `Transaction` account holds
the instructions, a `Proposal` collects votes per the threshold, and on execution the
program signs the instructions as the smart-account PDA. (For a single-shot path with
all signers present, see [synchronous execution](/operations/execute-transaction-sync).)

## Controlled vs. autonomous

- A **controlled** account has a `settings_authority` — a single key that can
  reconfigure it directly via the [`*AsAuthority`](/operations/authority/add-signer)
  instructions.
- An **autonomous** account has no settings authority (it's set to the default pubkey).
  It reconfigures itself through [settings transactions](/operations/settings/create),
  which go through the same propose → vote → execute flow.

You choose at creation by passing (or omitting) `settings_authority`. An authority can
later [renounce control](/operations/authority/set-new-settings-authority), permanently
converting a controlled account to autonomous.
