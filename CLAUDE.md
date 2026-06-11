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
        account_context.add_readonly_nonsigner(SquadsSmartAccounts::MAINNET_PROGRAM_ID)
      end

      # Called by TransactionComposer with a merged AccountContext.
      # Use context.index_of(pubkey) to resolve account positions.
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::SomeInstruction.build(
          param:          params[:param],
          account_a_index: context.index_of(params[:payer].to_s),
          account_b_index: context.index_of(params[:multisig].to_s),
          program_index:   context.index_of(SquadsSmartAccounts::MAINNET_PROGRAM_ID)
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
├── idl/            # squads_smart_account_program.json (Anchor IDL)
└── constants.rb    # MAINNET_PROGRAM_ID / DEVNET_PROGRAM_ID
```

## IDL

The Anchor IDL at `lib/solace/squads_smart_accounts/idl/squads_smart_account_program.json` is the source of truth for instruction names, accounts, and argument types. Keep it in sync with the deployed program:

```sh
rake idl:compare          # compares local IDL to mainnet
rake idl:compare[devnet]  # compare against devnet
```

Requires the `anchor` CLI to be installed.

## Tests

```sh
bundle exec rake          # runs all tests (default task)
SOLACE_PATH=../solace/lib bundle exec rake  # use local solace checkout
```

Tests use Minitest. Integration tests that hit a real validator use `test/support/solana_test_validator.rb`.
