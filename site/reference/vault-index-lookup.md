---
title: Vault Address Lookup
---

# Vault Address Lookup

Smart-account addresses are derived **one-way** from an index (`settings_seed`):

```
settings = PDA(["smart_account", "settings", u128(seed)])
vault    = PDA(["smart_account", settings, "smart_account", account_index])
```

Given a vault address you can't recover its index — the derivation isn't invertible.
But most users only ever saved their **smart account (vault) address**, and later need
their **index** and **settings address** back (to fetch settings, run the lifecycle,
etc.). `Solace::SquadsSmartAccounts::VaultIndex` solves this by precomputing the forward
map once and inverting it locally.

## When to use it

Reach for this when you have a vault address and need its `settings_seed` /
settings account — typically recovering an account a user identifies only by the
address that holds their funds. If you already have the index, you don't need it: just
derive forward with [`get_settings_address` / `get_smart_account_address`](/reference/pda-and-fetchers).

## Building the table

`VaultIndex.build` derives the default vault (`account_index 0`) for every seed in
`1..count` and writes a compact binary table — one 32-byte vault pubkey per record,
where the record at offset `o` is `settings_seed = o + 1`. The write is atomic, so an
interrupted build never leaves a half-written file.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `count` | Integer | no | `500_000` | Number of indices to cover (seeds `1..count`). |
| `path` | String | no | `default_path` | Output file (default: `vault-index.bin` in the current directory). |
| `progress` | Proc | no | `nil` | Optional `progress.call(done, count)`, invoked every 50k seeds. |

```ruby
require 'solace/squads_smart_accounts'

Solace::SquadsSmartAccounts::VaultIndex.build(
  count:    500_000,
  progress: ->(done, total) { puts "#{done} / #{total}" }
)
# => writes ./vault-index.bin
```

At 500,000 entries the file is **~16 MB** and takes **~3 minutes** to build
(single-threaded). The pubkeys are high-entropy, so the file does not compress. Build it
once and keep it.

## Looking up an address

`VaultIndex.lookup` loads the table into an in-memory hash (once per path, memoized) and
resolves a vault address. The settings address is re-derived from the recovered index.

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `vault_address` | #to_s | yes | — | The smart-account (vault) address to resolve. |
| `path` | String | no | `default_path` | The table file to read. |

**Returns** `{ index:, settings_address: }`, or `nil` if the address isn't in the table.
Raises if the table file doesn't exist (build it first).

```ruby
VaultIndex = Solace::SquadsSmartAccounts::VaultIndex

result = VaultIndex.lookup('EdMSvMoHfsemd2s7eHCrRnuM1dzPu2CpUrHJN98XYC9y')
# => { index: 1, settings_address: "41gqrPgijYycTaCCzKyLfvqikMEH9fzGCwZYAKQHvMbd" }

result[:index]            # => 1
result[:settings_address] # => the settings PDA for that account
```

## Limitations

- **Snapshot.** The table covers indices `1..count`. An address whose index is higher
  than `count`, or an account created after the build (the on-chain index keeps
  climbing), won't be found — rebuild with a larger `count` to extend coverage.
- **Default vault only.** Only the `account_index 0` vault is indexed. A saved sub-vault
  address (`account_index` 1–255) won't match.
- **Memory.** Lookups load the whole table into a hash (tens of MB of RAM for the 500k
  table); it's memoized, so repeated lookups are O(1).
