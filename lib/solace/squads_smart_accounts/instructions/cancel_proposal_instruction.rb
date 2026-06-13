# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    module Instructions
      # Encodes the `cancelProposal` instruction for the Squads Smart Account program.
      #
      # Registers a cancellation vote on an Approved proposal on behalf of a
      # signer with the Vote permission. Once cancellations reach the threshold
      # the proposal becomes Cancelled and its transaction can no longer execute.
      #
      # Accounts (in order):
      #   0. settings      — readonly, non-signer (consensus account)
      #   1. signer        — writable, signer (must have the Vote permission; pays any realloc)
      #   2. proposal      — writable, non-signer
      #   3. systemProgram — required here (funds the proposal realloc) — unlike
      #      approve/reject, where this optional account is absent
      #   4. program       — readonly, non-signer (the Squads program itself)
      #
      # Shares the VoteOnProposal account context and args with approve/reject;
      # the discriminator differs and systemProgram is present rather than absent.
      class CancelProposalInstruction
        # 8-byte Anchor discriminator: SHA256("global:cancel_proposal")[0..7]
        DISCRIMINATOR = [106, 74, 128, 146, 19, 65, 39, 23].freeze

        # Builds a {Solace::Instruction} for cancelProposal.
        #
        # @param memo [String, nil] Optional indexing memo.
        # @param settings_index [Integer] Account index of the settings account.
        # @param signer_index [Integer] Account index of the voting signer.
        # @param proposal_index [Integer] Account index of the proposal.
        # @param system_program_index [Integer] Account index of systemProgram.
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
