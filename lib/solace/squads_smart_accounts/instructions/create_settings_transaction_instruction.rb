# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `createSettingsTransaction` instruction for the Squads Smart
      # Account program.
      #
      # Stores a batch of SettingsActions on-chain as a SettingsTransaction, to be
      # applied later by `executeSettingsTransaction` once its proposal is
      # approved. Autonomous accounts only — controlled accounts use the
      # *AsAuthority instructions.
      #
      # Accounts (in order):
      #   0. settings      — writable, non-signer
      #   1. transaction   — writable, non-signer (SettingsTransaction PDA to create)
      #   2. creator       — readonly, signer (must be a signer with Initiate permission)
      #   3. rentPayer     — writable, signer (funds the new account's rent)
      #   4. systemProgram — readonly, non-signer
      #   5. program       — readonly, non-signer (the Squads program itself)
      #
      # The SettingsTransaction PDA shares the vault Transaction seeds
      # ["smart_account", settings, "transaction", u64(index)]; only the stored
      # account type differs.
      class CreateSettingsTransactionInstruction
        # 8-byte Anchor discriminator: SHA256("global:create_settings_transaction")[0..7]
        DISCRIMINATOR = [101, 168, 254, 203, 222, 102, 95, 192].freeze

        # Builds a {Solace::Instruction} for createSettingsTransaction.
        #
        # @param actions [Array<SettingsAction>] The settings actions to store.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param transaction_index [Integer] Account index of the SettingsTransaction PDA.
        # @param creator_index [Integer] Account index of the creator.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @return [Solace::Instruction]
        def self.build(
          actions:,
          memo:,
          settings_index:,
          transaction_index:,
          creator_index:,
          rent_payer_index:,
          system_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              transaction_index,
              creator_index,
              rent_payer_index,
              system_program_index,
              program_index
            ]

            ix.data = data(actions:, memo:)
          end
        end

        # Encodes the `CreateSettingsTransactionArgs { actions, memo }` in Borsh.
        #
        # @param actions [Array<SettingsAction>] The settings actions to store.
        # @param memo [String, nil] Optional indexing memo.
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(actions:, memo:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_settings_actions(actions) +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
