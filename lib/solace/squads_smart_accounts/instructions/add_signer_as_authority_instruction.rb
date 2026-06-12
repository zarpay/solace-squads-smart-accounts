# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `addSignerAsAuthority` instruction for the Squads Smart Account program.
      #
      # Adds a new signer (with a permission mask) to a controlled smart account.
      # Only callable by the account's settings authority — no consensus involved.
      #
      # IDL accounts (in order):
      #   0. settings          — writable, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. rentPayer         — writable, signer (pays for settings realloc)
      #   3. systemProgram     — readonly, non-signer
      #   4. program           — readonly, non-signer
      class AddSignerAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:add_signer_as_authority")[0..7]
        DISCRIMINATOR = [80, 198, 228, 154, 7, 234, 99, 56].freeze

        # Builds a {Solace::Instruction} for addSignerAsAuthority.
        #
        # @param new_signer [SmartAccountSigner] The signer to add (pubkey + permission mask).
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the settings authority.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          new_signer:,
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
            ix.data = data(new_signer:, memo:)
          end
        end

        # Encodes the `AddSignerArgs` struct in Borsh format.
        #
        # The signer is a bare struct (32-byte pubkey + 1-byte permission mask),
        # not a Vec — no length prefix.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(new_signer:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_pubkey(new_signer.pubkey) +
            [new_signer.permission] +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
