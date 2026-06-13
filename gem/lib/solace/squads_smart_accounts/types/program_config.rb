# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing the deserialized global ProgramConfig
    # account for the Squads Smart Account program. Fetching from the chain is
    # the Program layer's responsibility — see
    # Solace::Programs::SquadsSmartAccount#get_program_config.
    #
    # @example
    #   config = program.get_program_config
    #   config.treasury                   # => "SQDS4ep..."
    #   config.smart_account_creation_fee # => 10_000_000
    ProgramConfig = Data.define(
      :smart_account_index,        # Integer — running count of smart accounts created
      :authority,                  # String  — base58 pubkey that can update the config
      :smart_account_creation_fee, # Integer — lamports charged per smart account creation
      :treasury                    # String  — base58 pubkey that receives creation fees
    ) do
      # Deserializes a ProgramConfig from a stream of Borsh-encoded account data.
      #
      # @param io [IO, StringIO] Stream positioned at the start of the account data.
      # @return [ProgramConfig] The deserialized, frozen config value.
      def self.deserialize(io)
        io.read(8) # skip 8-byte Anchor discriminator

        new(
          smart_account_index:        Solace::Utils::Codecs.decode_le_u128(io),
          authority:                  Solace::Utils::Codecs.decode_pubkey(io),
          smart_account_creation_fee: Solace::Utils::Codecs.decode_le_u64(io),
          treasury:                   Solace::Utils::Codecs.decode_pubkey(io)
        )
      end
    end
  end
end
