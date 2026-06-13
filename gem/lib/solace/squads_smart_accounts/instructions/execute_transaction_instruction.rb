# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `executeTransaction` instruction for the Squads Smart Account program.
      #
      # Executes the inner instructions of an Approved proposal's stored
      # Transaction. The vault (smart account) PDA signs the inner instructions
      # via CPI — the program patches its signer bit at runtime — so it is passed
      # among the remaining accounts as a non-signer.
      #
      # Fixed accounts (in order):
      #   0. settings    — writable, non-signer (consensus account)
      #   1. proposal    — writable, non-signer
      #   2. transaction — readonly, non-signer
      #   3. signer      — readonly, signer (must have the Execute permission)
      #   4. program     — readonly, non-signer (the Squads program itself)
      #
      # Followed by the remaining accounts: the stored message's account_keys in
      # order, each writable per the message header and all as non-signers (the
      # lone message signer is the vault PDA, which the program signs via CPI).
      #
      # executeTransaction takes no arguments — its data is the discriminator only.
      class ExecuteTransactionInstruction
        # 8-byte Anchor discriminator: SHA256("global:execute_transaction")[0..7]
        DISCRIMINATOR = [231, 173, 49, 91, 235, 24, 68, 19].freeze

        # Builds a {Solace::Instruction} for executeTransaction.
        #
        # @param settings_index [Integer] Account index of the settings account.
        # @param proposal_index [Integer] Account index of the proposal.
        # @param transaction_index [Integer] Account index of the transaction PDA.
        # @param signer_index [Integer] Account index of the executing signer.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @param remaining_account_indices [Array<Integer>] Account indices of the message's
        #   account_keys, in stored order.
        # @return [Solace::Instruction]
        def self.build(
          settings_index:,
          proposal_index:,
          transaction_index:,
          signer_index:,
          program_index:,
          remaining_account_indices:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              proposal_index,
              transaction_index,
              signer_index,
              program_index
            ] + remaining_account_indices

            ix.data = data
          end
        end

        # Encodes the instruction data — the discriminator only; executeTransaction
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
