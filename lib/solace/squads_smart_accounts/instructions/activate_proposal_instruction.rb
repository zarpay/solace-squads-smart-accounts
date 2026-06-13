# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `activateProposal` instruction for the Squads Smart Account program.
      #
      # Moves a proposal from Draft to Active so it can be voted on. Only needed
      # for proposals created with `draft: true`; proposals created with
      # `draft: false` start Active. The signer must be a smart-account member
      # with the Initiate permission.
      #
      # Accounts (in order):
      #   0. settings — readonly, non-signer
      #   1. signer   — writable, signer (must have the Initiate permission)
      #   2. proposal — writable, non-signer
      #
      # NOTE: unlike the other proposal-lifecycle instructions, activateProposal
      # takes NO trailing `program` account (confirmed against the deployed
      # program's activate_proposal.rs) — the program is only the invoked program.
      class ActivateProposalInstruction
        # 8-byte Anchor discriminator: SHA256("global:activate_proposal")[0..7]
        DISCRIMINATOR = [90, 186, 203, 234, 70, 185, 191, 21].freeze

        # Builds a {Solace::Instruction} for activateProposal.
        #
        # @param settings_index [Integer] Account index of the settings account.
        # @param signer_index [Integer] Account index of the activating signer.
        # @param proposal_index [Integer] Account index of the proposal.
        # @param program_index [Integer] Account index of the Squads program (the invoked program).
        # @return [Solace::Instruction]
        def self.build(
          settings_index:,
          signer_index:,
          proposal_index:,
          program_index:
        )
          Solace::Instruction.new.tap do |ix|
            ix.program_index = program_index
            ix.accounts      = [
              settings_index,
              signer_index,
              proposal_index
            ]

            ix.data = data
          end
        end

        # Encodes the instruction data — the discriminator only; activateProposal
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
