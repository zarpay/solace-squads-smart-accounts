# frozen_string_literal: true

module Solace
  module Programs
    # Client for interacting with the Squads Smart Account program.
    #
    # This client provides methods for interacting with the Squads Smart Account
    # program, including deriving the program's PDAs. Address derivation is the
    # Program layer's responsibility — composers receive resolved addresses.
    #
    # @example Derive the settings address for the next smart account
    #   program_config = Solace::SquadsSmartAccounts::ProgramConfig.load(connection)
    #
    #   settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
    #     settings_seed: program_config.smart_account_index + 1
    #   )
    #
    # @see Solace::SquadsSmartAccounts
    class SquadsSmartAccount < Base
      class << self
        # Gets the address of the settings PDA for a given settings seed.
        #
        # The seed is encoded as a 16-byte little-endian u128, matching the
        # on-chain derivation ["smart_account", "settings", seed.to_le_bytes()].
        #
        # @param settings_seed [Integer] ProgramConfig#smart_account_index + 1 at composition time.
        # @return [Array<String, Integer>] The settings address and bump seed.
        def get_settings_address(settings_seed:)
          Solace::Utils::PDA.find_program_address(
            ['smart_account', 'settings', Solace::Utils::Codecs.encode_le_u128(settings_seed).bytes],
            Solace::SquadsSmartAccounts::PROGRAM_ID
          )
        end
      end

      # Initializes a new Squads Smart Account client.
      #
      # @param connection [Solace::Connection] The connection to the Solana cluster.
      def initialize(connection:)
        super(connection: connection, program_id: Solace::SquadsSmartAccounts::PROGRAM_ID)
      end

      # Alias method for get_settings_address
      #
      # @param options [Hash] A hash of options for the get_settings_address class method
      # @return [Array<String, Integer>] The settings address and bump seed.
      def get_settings_address(**options)
        self.class.get_settings_address(**options)
      end
    end
  end
end
