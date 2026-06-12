# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `executeSettingsTransactionSync` instruction for the Squads
      # Smart Account program.
      #
      # Synchronously applies a batch of SettingsActions to an autonomous smart
      # account, provided the transaction is co-signed by enough signers to reach
      # the settings threshold. The program rejects controlled accounts
      # (NotSupportedForControlled) — those use the *AsAuthority instructions.
      #
      # IDL accounts (in order):
      #   0. settings      — writable, non-signer
      #   1. rentPayer     — writable, signer (pays for settings realloc)
      #   2. systemProgram — readonly, non-signer
      #   3. program       — readonly, non-signer
      #   Remaining accounts (in exact order):
      #   4. The first `num_signers` accounts must be the threshold co-signers.
      #      (SpendingLimit PDAs would follow for spending-limit actions — not
      #      supported by this gem yet.)
      class ExecuteSettingsTransactionSyncInstruction
        # 8-byte Anchor discriminator: SHA256("global:execute_settings_transaction_sync")[0..7]
        DISCRIMINATOR = [138, 209, 64, 163, 79, 67, 233, 76].freeze

        # Builds a {Solace::Instruction} for executeSettingsTransactionSync.
        #
        # @param num_signers [Integer] Number of co-signers proving threshold consensus.
        # @param actions [Array<SettingsAction>] The settings actions to apply atomically.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program.
        # @param signer_indices [Array<Integer>] Account indices of the threshold co-signers.
        # @return [Solace::Instruction]
        def self.build(
          num_signers:,
          actions:,
          memo:,
          settings_index:,
          rent_payer_index:,
          system_program_index:,
          program_index:,
          signer_indices:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              rent_payer_index,
              system_program_index,
              program_index,
              *signer_indices
            ]
            ix.data = data(num_signers:, actions:, memo:)
          end
        end

        # Encodes the `SyncSettingsTransactionArgs` struct in Borsh format.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(num_signers:, actions:, memo:)
          DISCRIMINATOR +
            [num_signers] +
            Solace::Utils::Codecs.encode_settings_actions(actions) +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
