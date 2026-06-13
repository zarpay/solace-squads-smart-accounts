# solace-squads-smart-accounts

Extension gem for [`solace`](https://github.com/sebscholl/solace) that adds support for the [Squads Smart Account](https://squads.so/) program on Solana (`SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG`).

## Solace Architecture

`solace` has four layered abstractions. This gem lives in the middle two:

| Layer | Class | Role |
|---|---|---|
| Primitives | `Transaction`, `Message`, `Instruction` | Raw Solana protocol |
| **Instruction Builders** | `lib/*/instructions/**` | Encode one program instruction |
| **Composers** | `lib/*/composers/**` | Compose instructions into transactions |
| Programs | `Solace::Programs::Base` subclasses | Full send-and-sign clients |

## Adding Instructions

Instruction builders are stateless service objects. No base class — follow the convention:

```ruby
module Solace
  module SquadsSmartAccounts
    module Instructions
      class SomeInstruction
        DISCRIMINATOR = [1, 2, 3, 4, 5, 6, 7, 8].freeze  # Anchor 8-byte discriminator

        def self.build(param:, account_a_index:, account_b_index:, program_index:)
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [account_a_index, account_b_index]
            ix.data          = data(param)
          end
        end

        def self.data(param)
          DISCRIMINATOR + Solace::Utils::Codecs.encode_le_u64(param)
        end
      end
    end
  end
end
```

Key encoding helpers from `Solace::Utils::Codecs`: `encode_le_u64`, `encode_le_u32`, `encode_compact_u16`, `bytes_to_base58`, `base58_to_bytes`.

## Adding Composers

Composers inherit from `Solace::Composers::Base` and implement exactly two methods:

```ruby
module Solace
  module Composers
    class SquadsSmartAccountsSomeComposer < Base
      # Declare all accounts needed by this instruction.
      # account_context methods: add_writable_signer, add_writable_nonsigner,
      #                          add_readonly_signer, add_readonly_nonsigner, set_fee_payer
      def setup_accounts
        account_context.add_writable_signer(params[:payer].to_s)
        account_context.add_writable_nonsigner(params[:multisig].to_s)
        account_context.add_readonly_nonsigner(SquadsSmartAccounts::PROGRAM_ID)
      end

      # Called by TransactionComposer with a merged AccountContext.
      # Use context.index_of(pubkey) to resolve account positions.
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::SomeInstruction.build(
          param:          params[:param],
          account_a_index: context.index_of(params[:payer].to_s),
          account_b_index: context.index_of(params[:multisig].to_s),
          program_index:   context.index_of(SquadsSmartAccounts::PROGRAM_ID)
        )
      end
    end
  end
end
```

`params` is the hash passed to the composer's constructor. Use `.to_s` on pubkeys — `AccountContext` keys by string.

## File Layout

```
lib/solace/squads_smart_accounts/
├── instructions/   # one file per on-chain instruction
├── composers/      # one file per composer (mirrors instructions/)
├── programs/       # Solace::Programs::Base subclasses (PDA derivation, send-and-sign clients)
├── types/          # account/value types (ProgramConfig, Settings, Permissions, ...)
├── idl/            # squads_smart_account_program.json (Anchor IDL)
└── constants.rb    # PROGRAM_ID (canonical) + MAINNET_PROGRAM_ID / DEVNET_PROGRAM_ID aliases
```

PDA derivation belongs in the Program layer (`Solace::Programs::SquadsSmartAccount.get_settings_address`), never in composers — composers receive resolved addresses as params and expose every param/constant through a documented named accessor method.

## Progress

`INSTRUCTIONS.md` tracks implementation status of all 37 IDL instructions. Check off an instruction when its builder, composer, and integration tests are complete.

## IDL

The Anchor IDL at `lib/solace/squads_smart_accounts/idl/squads_smart_account_program.json` is the source of truth for instruction names, accounts, and argument types. Keep it in sync with the deployed program:

```sh
rake idl:compare   # fetches upstream IDL from GitHub and compares to local copy
```

## Tests

```sh
bundle exec rake   # runs all tests (default task); solace comes from RubyGems
```

All commands run from the `gem/` directory (the gem lives in `gem/`; the docs
site lives in `site/`).

Tests use Minitest. The test suite automatically starts a local `solana-test-validator` with a fresh ledger (`--reset`) and the Squads program cloned from mainnet-beta, funds the fixture accounts (`test/support/bootstrap.rb`), then stops the validator after the run. No state persists between runs. Always run the tests after making changes — don't wait for the user to ask.

Integration tests live in `test/` and follow the `*_test.rb` naming convention. The validator support script is at `test/support/solana_test_validator.rb`. If a validator is already running it is reused (and not reset) — kill leftover validators if tests behave strangely.
