# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `rejectProposal` instruction for the Squads Smart Account program.
    #
    # Casts a rejection vote on an active proposal. The signer must be a smart
    # account member with the Vote permission.
    #
    # Required params:
    #   :settings [#to_s]          Base58 address of the settings account.
    #   :signer   [#to_s, Keypair] The voting signer (must sign).
    #   :proposal [#to_s]          The Proposal PDA to vote on.
    #
    # Optional params:
    #   :memo [String] Indexing memo (default: nil).
    class SquadsSmartAccountsRejectProposalComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the voting signer address from the params
      #
      # @return [String] The signer address
      def signer
        params[:signer].to_s
      end

      # Extracts the proposal PDA address from the params
      #
      # @return [String] The proposal address
      def proposal
        params[:proposal].to_s
      end

      # Extracts the memo from the params
      #
      # @return [String, nil] The memo
      def memo
        params[:memo]
      end

      # Returns the Squads Smart Account program id from the constants. The
      # systemProgram account is optional and absent for a vote, so this id
      # also fills that slot.
      #
      # @return [String] The Squads Smart Account program id
      def program_id
        SquadsSmartAccounts::PROGRAM_ID
      end

      # Declares all accounts required by this instruction.
      def setup_accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_writable_signer(signer)
        account_context.add_writable_nonsigner(proposal)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices. The absent
      # systemProgram slot resolves to the Squads program id index.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::RejectProposalInstruction.build(
          memo:,
          settings_index:       context.index_of(settings),
          signer_index:         context.index_of(signer),
          proposal_index:       context.index_of(proposal),
          system_program_index: context.index_of(program_id),
          program_index:        context.index_of(program_id)
        )
      end
    end
  end
end
