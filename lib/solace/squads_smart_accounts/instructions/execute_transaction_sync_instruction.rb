# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `executeTransactionSync` instruction for the Squads Smart Account program.
      #
      # Synchronously executes inner instructions signed by a smart account (vault)
      # PDA, provided the transaction is co-signed by enough signers to reach the
      # settings threshold. Skips the proposal/voting lifecycle entirely.
      #
      # IDL accounts (in order):
      #   0. settings — readonly, non-signer
      #   1. program  — readonly, non-signer
      #   Remaining accounts (in exact order):
      #   2. The first `num_signers` accounts must be the threshold signers.
      #   3. All accounts referenced by the inner instructions. Inner instruction
      #      indexes are relative to the FULL remaining-accounts list, signers
      #      included (0 = the first signer).
      class ExecuteTransactionSyncInstruction
        # 8-byte Anchor discriminator: SHA256("global:execute_transaction_sync")[0..7]
        DISCRIMINATOR = [43, 102, 248, 89, 231, 97, 104, 134].freeze

        # Builds a {Solace::Instruction} for executeTransactionSync.
        #
        # @param account_index [Integer] Index of the vault the inner instructions spend from.
        # @param num_signers [Integer] Number of signer accounts proving threshold consensus.
        # @param instructions [Array<Solace::Instruction>] Pre-compiled inner instructions whose
        #   program_index and accounts are indexes into the full remaining-accounts list.
        # @param settings_index [Integer] Account index of the settings account.
        # @param program_index [Integer] Account index of the Squads program.
        # @param signer_indices [Array<Integer>] Account indices of the threshold signers.
        # @param remaining_account_indices [Array<Integer>] Account indices of every account
        #   referenced by the inner instructions, in compiled order.
        # @return [Solace::Instruction]
        def self.build(
          account_index:,
          num_signers:,
          instructions:,
          settings_index:,
          program_index:,
          signer_indices:,
          remaining_account_indices:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              program_index,
              *signer_indices,
              *remaining_account_indices
            ]
            ix.data = data(
              account_index:,
              num_signers:,
              instructions:
            )
          end
        end

        # Encodes the `SyncTransactionArgs` struct in Borsh format.
        #
        # The inner instructions are double-wrapped: serialized as a
        # SmallVec<u8, CompiledInstruction>, then embedded as a Borsh bytes
        # field (u32 LE length prefix).
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(account_index:, num_signers:, instructions:)
          DISCRIMINATOR +
            [account_index] +
            [num_signers] +
            Solace::Utils::Codecs.encode_bytes(
              Solace::Utils::Codecs.encode_compiled_instructions(instructions)
            )
        end
      end
    end
  end
end
