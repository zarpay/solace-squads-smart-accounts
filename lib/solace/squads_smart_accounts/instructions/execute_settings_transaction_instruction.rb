# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `executeSettingsTransaction` instruction for the Squads Smart
      # Account program.
      #
      # Applies the stored SettingsActions of an Approved proposal's
      # SettingsTransaction to the settings account. Takes no arguments — the
      # actions are read from the stored transaction on-chain.
      #
      # Accounts (in order):
      #   0. settings      — writable, non-signer
      #   1. signer        — readonly, signer (must have the Execute permission)
      #   2. proposal      — writable, non-signer
      #   3. transaction   — readonly, non-signer (the SettingsTransaction)
      #   4. rentPayer     — writable, signer (funds any settings realloc)
      #   5. systemProgram — readonly, non-signer (needed for realloc)
      #   6. program       — readonly, non-signer (the Squads program itself)
      #   Remaining accounts: SpendingLimit PDAs initialized/closed by
      #     AddSpendingLimit / RemoveSpendingLimit actions, in action order.
      #
      # rentPayer and systemProgram are optional in the program, but this builder
      # always includes them so a realloc-triggering action never fails.
      class ExecuteSettingsTransactionInstruction
        # 8-byte Anchor discriminator: SHA256("global:execute_settings_transaction")[0..7]
        DISCRIMINATOR = [131, 210, 27, 88, 27, 204, 143, 189].freeze

        # Builds a {Solace::Instruction} for executeSettingsTransaction.
        #
        # @param settings_index [Integer] Account index of the settings account.
        # @param signer_index [Integer] Account index of the executing signer.
        # @param proposal_index [Integer] Account index of the proposal.
        # @param transaction_index [Integer] Account index of the SettingsTransaction PDA.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @param spending_limit_indices [Array<Integer>] Account indices of SpendingLimit
        #   PDAs touched by the actions, in action order (default: []).
        # @return [Solace::Instruction]
        def self.build(
          settings_index:,
          signer_index:,
          proposal_index:,
          transaction_index:,
          rent_payer_index:,
          system_program_index:,
          program_index:,
          spending_limit_indices: []
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              signer_index,
              proposal_index,
              transaction_index,
              rent_payer_index,
              system_program_index,
              program_index,
              *spending_limit_indices
            ]

            ix.data = data
          end
        end

        # Encodes the instruction data — the discriminator only;
        # executeSettingsTransaction takes no arguments.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data
          DISCRIMINATOR
        end
      end
    end
  end
end
