# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing the deserialized global ProgramConfig
    # account for the Squads Smart Account program.
    #
    # @example
    #   config = Solace::SquadsSmartAccounts::ProgramConfig.load(connection)
    #   config.treasury                   # => "SQDS4ep..."
    #   config.smart_account_creation_fee # => 10_000_000
    ProgramConfig = Data.define(
      :smart_account_index,        # Integer — running count of smart accounts created
      :authority,                  # String  — base58 pubkey that can update the config
      :smart_account_creation_fee, # Integer — lamports charged per smart account creation
      :treasury                    # String  — base58 pubkey that receives creation fees
    ) do
      # Fetches and deserializes the ProgramConfig account from the chain.
      #
      # @param connection [Solace::Connection] An active RPC connection.
      # @return [ProgramConfig] The deserialized, frozen config value.
      # @raise [RuntimeError] If the account does not exist at the expected address.
      def self.load(connection)
        account = connection.get_account_info(PROGRAM_CONFIG_ADDRESS)
        raise 'ProgramConfig account not found — has the validator been bootstrapped?' unless account

        # Build a stream from the base64-encoded account data for sequential reads.
        io = Solace::Utils::Codecs.base64_to_bytestream(account['data'][0])

        io.read(8) # skip 8-byte Anchor discriminator

        # u128 stored as two consecutive little-endian u64 words.
        lo, hi = io.read(16).unpack('Q<Q<')

        new(
          smart_account_index:        lo + (hi << 64),
          authority:                  Solace::Utils::Codecs.bytes_to_base58(io.read(32).bytes),
          smart_account_creation_fee: Solace::Utils::Codecs.decode_le_u64(io),
          treasury:                   Solace::Utils::Codecs.bytes_to_base58(io.read(32).bytes)
        )
      end
    end
  end
end
