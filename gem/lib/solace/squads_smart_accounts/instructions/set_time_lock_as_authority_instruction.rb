# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `setTimeLockAsAuthority` instruction for the Squads Smart Account program.
      #
      # Sets the time lock (seconds between proposal approval and execution) of a
      # controlled smart account. Only callable by the account's settings
      # authority — no consensus involved.
      #
      # IDL accounts (in order):
      #   0. settings          — writable, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. rentPayer         — writable, signer (pays for settings realloc)
      #   3. systemProgram     — readonly, non-signer
      #   4. program           — readonly, non-signer
      class SetTimeLockAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:set_time_lock_as_authority")[0..7]
        DISCRIMINATOR = [2, 234, 93, 93, 40, 92, 31, 234].freeze

        # Builds a {Solace::Instruction} for setTimeLockAsAuthority.
        #
        # @param time_lock [Integer] Seconds between approval and execution (u32).
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the settings authority.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          time_lock:,
          memo:,
          settings_index:,
          settings_authority_index:,
          rent_payer_index:,
          system_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              settings_authority_index,
              rent_payer_index,
              system_program_index,
              program_index
            ]

            ix.data = data(time_lock:, memo:)
          end
        end

        # Encodes the `SetTimeLockArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(time_lock:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_le_u32(time_lock).bytes +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
