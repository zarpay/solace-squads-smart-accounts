# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing a deserialized SpendingLimit account —
    # a pre-authorized allowance letting designated signers move funds from a
    # vault without consensus. Fetching from the chain is the Program layer's
    # responsibility — see Solace::Programs::SquadsSmartAccount#get_spending_limit.
    #
    # @example
    #   limit = program.get_spending_limit(spending_limit_address: address)
    #   limit.amount           # => 500_000_000
    #   limit.remaining_amount # => 300_000_000
    SpendingLimit = Data.define(
      :settings,         # String  — base58 settings account this limit belongs to
      :seed,             # String  — base58 pubkey the PDA was seeded with
      :account_index,    # Integer — vault index the limit spends from
      :mint,             # String  — base58 mint; DEFAULT_PUBKEY means SOL
      :amount,           # Integer — amount spendable per period (mint decimals)
      :period,           # Integer — Period enum value (reset cadence)
      :remaining_amount, # Integer — amount left in the current period
      :last_reset,       # Integer — unix timestamp of the last period reset
      :bump,             # Integer — spending limit PDA bump seed
      :signers,          # Array<String> — base58 pubkeys allowed to use the limit
      :destinations,     # Array<String> — allowed destinations; empty = any
      :expiration        # Integer — unix expiration timestamp; I64_MAX = never
    ) do
      # Deserializes a SpendingLimit from a stream of Borsh-encoded account data.
      #
      # @param io [IO, StringIO] Stream positioned at the start of the account data.
      # @return [SpendingLimit] The deserialized, frozen value.
      def self.deserialize(io)
        io.read(8) # skip 8-byte Anchor discriminator

        new(
          settings:         Solace::Utils::Codecs.decode_pubkey(io),
          seed:             Solace::Utils::Codecs.decode_pubkey(io),
          account_index:    Solace::Utils::Codecs.decode_u8(io),
          mint:             Solace::Utils::Codecs.decode_pubkey(io),
          amount:           Solace::Utils::Codecs.decode_le_u64(io),
          period:           Solace::Utils::Codecs.decode_u8(io),
          remaining_amount: Solace::Utils::Codecs.decode_le_u64(io),
          last_reset:       Solace::Utils::Codecs.decode_le_i64(io),
          bump:             Solace::Utils::Codecs.decode_u8(io),
          signers:          Solace::Utils::Codecs.decode_vec_pubkeys(io),
          destinations:     Solace::Utils::Codecs.decode_vec_pubkeys(io),
          expiration:       Solace::Utils::Codecs.decode_le_i64(io)
        )
      end
    end
  end
end
