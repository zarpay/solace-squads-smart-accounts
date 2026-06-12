# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `removeSignerAsAuthority` instruction for the Squads Smart Account program.
      #
      # Removes a signer from a controlled smart account. Only callable by the
      # account's settings authority — no consensus involved. The program rejects
      # removing the last signer or breaking the threshold invariant.
      #
      # IDL accounts (in order):
      #   0. settings          — writable, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. rentPayer         — writable, signer (pays for settings realloc)
      #   3. systemProgram     — readonly, non-signer
      #   4. program           — readonly, non-signer
      class RemoveSignerAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:remove_signer_as_authority")[0..7]
        DISCRIMINATOR = [58, 19, 149, 16, 181, 16, 125, 148].freeze

        # Builds a {Solace::Instruction} for removeSignerAsAuthority.
        #
        # @param old_signer [String] Base58 pubkey of the signer to remove.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the settings authority.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          old_signer:,
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
            ix.data = data(old_signer:, memo:)
          end
        end

        # Encodes the `RemoveSignerArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(old_signer:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_pubkey(old_signer) +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
