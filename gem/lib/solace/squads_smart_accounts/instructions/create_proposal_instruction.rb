# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `createProposal` instruction for the Squads Smart Account program.
      #
      # Creates the Proposal account that tracks votes for a previously stored
      # Transaction. A proposal created with `draft: false` starts `Active` (ready
      # to vote); `draft: true` starts `Draft` and must be activated first.
      #
      # Accounts (in order):
      #   0. settings      — readonly, non-signer (consensus account)
      #   1. proposal      — writable, non-signer (PDA to be created)
      #   2. creator       — readonly, signer (must be a smart-account signer)
      #   3. rentPayer     — writable, signer (funds the new account's rent)
      #   4. systemProgram — readonly, non-signer
      #   5. program       — readonly, non-signer (the Squads program itself)
      #
      # The trailing `program` account is required by the deployed program and is
      # not in the bundled IDL (see memory `reference-deployed-program-drift`).
      class CreateProposalInstruction
        # 8-byte Anchor discriminator: SHA256("global:create_proposal")[0..7]
        DISCRIMINATOR = [132, 116, 68, 174, 216, 160, 198, 22].freeze

        # Builds a {Solace::Instruction} for createProposal.
        #
        # @param transaction_index [Integer] Index of the transaction this proposal tracks (u64).
        # @param draft [Boolean] Whether to initialize the proposal as Draft (vs Active).
        # @param settings_index [Integer] Account index of the settings account.
        # @param proposal_index [Integer] Account index of the proposal PDA.
        # @param creator_index [Integer] Account index of the creator.
        # @param rent_payer_index [Integer] Account index of the rent payer.
        # @param system_program_index [Integer] Account index of systemProgram.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @return [Solace::Instruction]
        def self.build(
          transaction_index:,
          draft:,
          settings_index:,
          proposal_index:,
          creator_index:,
          rent_payer_index:,
          system_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              proposal_index,
              creator_index,
              rent_payer_index,
              system_program_index,
              program_index
            ]

            ix.data = data(
              transaction_index:,
              draft:
            )
          end
        end

        # Encodes the `CreateProposalArgs { transaction_index: u64, draft: bool }` in Borsh.
        #
        # @param transaction_index [Integer] Index of the transaction this proposal tracks (u64).
        # @param draft [Boolean] Whether to initialize the proposal as Draft.
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(transaction_index:, draft:)
          DISCRIMINATOR +
            Solace::Utils::Codecs.encode_le_u64(transaction_index).bytes +
            Solace::Utils::Codecs.encode_bool(draft)
        end
      end
    end
  end
end
