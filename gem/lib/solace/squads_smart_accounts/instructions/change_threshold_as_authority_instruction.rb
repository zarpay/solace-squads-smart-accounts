# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `changeThresholdAsAuthority` instruction for the Squads Smart Account program.
      #
      # Changes the approval threshold of a controlled smart account. Only callable
      # by the account's settings authority — no consensus involved. The program
      # rejects thresholds outside 1..(number of voting signers).
      #
      # IDL accounts (in order):
      #   0. settings          — writable, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. rentPayer         — writable, signer (pays for settings realloc)
      #   3. systemProgram     — readonly, non-signer
      #   4. program           — readonly, non-signer
      class ChangeThresholdAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:change_threshold_as_authority")[0..7]
        DISCRIMINATOR = [51, 141, 78, 133, 70, 47, 95, 124].freeze

        # Builds a {Solace::Instruction} for changeThresholdAsAuthority.
        #
        # @param new_threshold [Integer] The new approval threshold (u16).
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the settings authority.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          new_threshold:,
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

            ix.data = data(new_threshold:, memo:)
          end
        end

        # Encodes the `ChangeThresholdArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(new_threshold:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_le_u16(new_threshold).bytes +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
