# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `approveProposal` instruction for the Squads Smart Account program.
      #
      # Registers an approval vote on a proposal on behalf of a signer with the
      # Vote permission. Once approvals reach the settings threshold the proposal
      # becomes Approved and (after the time lock) its transaction can execute.
      #
      # Accounts (in order):
      #   0. settings      — writable, non-signer (consensus account)
      #   1. signer        — writable, signer (must have the Vote permission)
      #   2. proposal      — writable, non-signer
      #   3. systemProgram — optional; absent here, so the Squads program id fills the slot
      #   4. program       — readonly, non-signer (the Squads program itself)
      #
      # The trailing `program` account and the absent-optional-as-program-id slot
      # follow the deployed program (see memory `reference-deployed-program-drift`).
      class ApproveProposalInstruction
        # 8-byte Anchor discriminator: SHA256("global:approve_proposal")[0..7]
        DISCRIMINATOR = [136, 108, 102, 85, 98, 114, 7, 147].freeze

        # Builds a {Solace::Instruction} for approveProposal.
        #
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param signer_index [Integer] Account index of the voting signer.
        # @param proposal_index [Integer] Account index of the proposal.
        # @param system_program_index [Integer] Account index for the (absent) systemProgram slot.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @return [Solace::Instruction]
        def self.build(
          memo:,
          settings_index:,
          signer_index:,
          proposal_index:,
          system_program_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              signer_index,
              proposal_index,
              system_program_index,
              program_index
            ]

            ix.data = data(memo:)
          end
        end

        # Encodes the `VoteOnProposalArgs { memo: Option<String> }` in Borsh.
        #
        # @param memo [String, nil] Optional indexing memo.
        # @return [Array<Integer>] Byte array of the encoded instruction data.
        def self.data(memo:)
          DISCRIMINATOR + Solace::Utils::Codecs.encode_option_string(memo)
        end
      end
    end
  end
end
