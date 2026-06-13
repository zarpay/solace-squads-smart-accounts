# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `removeSpendingLimitAsAuthority` instruction for the Squads
      # Smart Account program.
      #
      # Closes a SpendingLimit PDA, refunding its rent to the rent collector.
      # Only callable by the account's settings authority — no consensus involved.
      #
      # IDL accounts (in order):
      #   0. settings          — readonly, non-signer
      #   1. settingsAuthority — readonly, signer
      #   2. spendingLimit     — writable, non-signer (closed by the instruction)
      #   3. rentCollector     — writable, non-signer (receives the rent refund)
      #   4. program           — readonly, non-signer
      class RemoveSpendingLimitAsAuthorityInstruction
        # 8-byte Anchor discriminator: SHA256("global:remove_spending_limit_as_authority")[0..7]
        DISCRIMINATOR = [94, 32, 68, 127, 251, 44, 145, 7].freeze

        # Builds a {Solace::Instruction} for removeSpendingLimitAsAuthority.
        #
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param settings_authority_index [Integer] Account index of the settings authority.
        # @param spending_limit_index [Integer] Account index of the SpendingLimit PDA.
        # @param rent_collector_index [Integer] Account index of the rent collector.
        # @param program_index [Integer] Account index of the Squads program.
        # @return [Solace::Instruction]
        def self.build(
          memo:,
          settings_index:,
          settings_authority_index:,
          spending_limit_index:,
          rent_collector_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              settings_authority_index,
              spending_limit_index,
              rent_collector_index,
              program_index
            ]

            ix.data = data(memo:)
          end
        end

        # Encodes the `RemoveSpendingLimitArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(memo:)
          DISCRIMINATOR + Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
