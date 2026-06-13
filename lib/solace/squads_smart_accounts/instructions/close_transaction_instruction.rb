# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `closeTransaction` instruction for the Squads Smart Account program.
      #
      # Closes a vault Transaction and its associated Proposal, refunding their
      # rent. Closeable once the proposal is in a terminal state (Executed,
      # Rejected, or Cancelled) or is stale and NOT Approved — an Approved vault
      # proposal can never be closed because it can still execute (this is the key
      # difference from closeSettingsTransaction). Takes no arguments and requires
      # no smart-account signer — only the fee payer signs.
      #
      # Accounts (in order):
      #   0. settings                 — readonly, non-signer (the consensus account)
      #   1. proposal                 — writable, non-signer (closed; rent → proposalRentCollector)
      #   2. transaction              — writable, non-signer (closed; rent → transactionRentCollector)
      #   3. proposalRentCollector    — writable, non-signer (receives the proposal rent)
      #   4. transactionRentCollector — writable, non-signer (must equal transaction.rent_collector)
      #   5. systemProgram            — readonly, non-signer
      #   6. program                  — readonly, non-signer (the Squads program itself)
      class CloseTransactionInstruction
        # 8-byte Anchor discriminator: SHA256("global:close_transaction")[0..7]
        DISCRIMINATOR = [97, 46, 152, 170, 42, 215, 192, 218].freeze

        # Builds a {Solace::Instruction} for closeTransaction.
        #
        # @param settings_index [Integer] Account index of the settings (consensus) account.
        # @param proposal_index [Integer] Account index of the proposal.
        # @param transaction_index [Integer] Account index of the vault Transaction PDA.
        # @param proposal_rent_collector_index [Integer] Account index of the proposal rent collector.
        # @param transaction_rent_collector_index [Integer] Account index of the transaction rent collector.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @return [Solace::Instruction]
        def self.build(
          settings_index:,
          proposal_index:,
          transaction_index:,
          proposal_rent_collector_index:,
          transaction_rent_collector_index:,
          system_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              proposal_index,
              transaction_index,
              proposal_rent_collector_index,
              transaction_rent_collector_index,
              system_program_index,
              program_index
            ]

            ix.data = data
          end
        end

        # Encodes the instruction data — the discriminator only; closeTransaction
        # takes no arguments.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data
          DISCRIMINATOR
        end
      end
    end
  end
end
