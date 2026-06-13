# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `createTransaction` instruction for the Squads Smart Account program.
      #
      # Stores a pending vault transaction (a compiled TransactionMessage) on-chain.
      # The transaction does not execute here — it awaits a proposal and approvals.
      #
      # IDL accounts (in order):
      #   0. settings      — writable, non-signer
      #   1. transaction   — writable, non-signer (PDA to be created)
      #   2. creator       — readonly, signer
      #   3. rentPayer     — writable, signer (funds the new account's rent)
      #   4. systemProgram — readonly, non-signer
      #   5. program       — readonly, non-signer (the Squads program itself)
      #
      # NOTE: the bundled IDL is stale for this instruction. The deployed program
      # is the newer version that (a) models the args as a `TransactionPayload`
      # enum variant and (b) requires the Squads `program` as a trailing account.
      # Both are reflected here.
      class CreateTransactionInstruction
        # 8-byte Anchor discriminator: SHA256("global:create_transaction")[0..7]
        DISCRIMINATOR = [227, 193, 53, 239, 55, 126, 112, 105].freeze

        # Builds a {Solace::Instruction} for createTransaction.
        #
        # @param account_index [Integer] Vault index the inner message spends from.
        # @param ephemeral_signers [Integer] Number of ephemeral signer PDAs (0 for simple messages).
        # @param transaction_message [Array<Integer>] The serialized TransactionMessage bytes.
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param transaction_index [Integer] Account index of the transaction PDA.
        # @param creator_index [Integer] Account index of the creator.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @return [Solace::Instruction]
        def self.build(
          account_index:,
          ephemeral_signers:,
          transaction_message:,
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

            ix.data = data(
              account_index:,
              ephemeral_signers:,
              transaction_message:,
              memo:
            )
          end
        end

        # Encodes the `CreateTransactionArgs::TransactionPayload` variant in Borsh.
        #
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(
          account_index:,
          ephemeral_signers:,
          transaction_message:,
          memo:
        )
          DISCRIMINATOR +
            # Borsh enum variant index for `CreateTransactionArgs::TransactionPayload`.
            # The deployed program models the args as an enum (TransactionPayload |
            # PolicyPayload) even though the bundled IDL still describes the legacy
            # flat struct — so the serialized data leads with this variant byte.
            [0] +
            [account_index] +
            [ephemeral_signers] +
            Solace::Utils::Codecs.encode_bytes(transaction_message) +
            Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
