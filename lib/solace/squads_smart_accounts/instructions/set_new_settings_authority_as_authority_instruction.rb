# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `setNewSettingsAuthorityAsAuthority` instruction for the Squads
      # Smart Account program.
      #
      # Hands the settings authority of a controlled smart account to a new key.
      # Only callable by the current settings authority — no consensus involved.
      #
      # IDL accounts (in order):
      #   0. settings          — writable, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. rentPayer         — writable, signer (pays for settings realloc)
      #   3. systemProgram     — readonly, non-signer
      #   4. program           — readonly, non-signer
      class SetNewSettingsAuthorityAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:set_new_settings_authority_as_authority")[0..7]
        DISCRIMINATOR = [221, 112, 133, 229, 146, 58, 90, 56].freeze

        # Builds a {Solace::Instruction} for setNewSettingsAuthorityAsAuthority.
        #
        # @param new_settings_authority [String] Base58 pubkey of the new settings authority.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the current settings authority.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          new_settings_authority:,
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

            ix.data = data(new_settings_authority:, memo:)
          end
        end

        # Encodes the `SetNewSettingsAuthorityArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(new_settings_authority:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_pubkey(new_settings_authority) +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
