# frozen_string_literal: true

module Solace
  module Composers
    # Composes an `activateProposal` instruction for the Squads Smart Account program.
    #
    # Moves a Draft proposal to Active. The signer must be a smart-account member
    # with the Initiate permission. Only needed for proposals created as drafts.
    #
    # Required params:
    #   :settings [#to_s]          Base58 address of the settings account.
    #   :signer   [#to_s, Keypair] The activating signer (must sign).
    #   :proposal [#to_s]          The Proposal PDA to activate.
    class SquadsSmartAccountsActivateProposalComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the activating signer address from the params
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

      # Returns the Squads Smart Account program id from the constants
      #
      # @return [String] The Squads Smart Account program id
      def program_id
        SquadsSmartAccounts::PROGRAM_ID
      end

      # Declares all accounts required by this instruction. The Squads program
      # is registered so it appears in the message account keys (it is the
      # invoked program), but — unlike the other proposal instructions — it is
      # NOT included in this instruction's account-metas list (no trailing
      # program account).
      def setup_accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_writable_signer(signer)
        account_context.add_writable_nonsigner(proposal)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::ActivateProposalInstruction.build(
          settings_index: context.index_of(settings),
          signer_index:   context.index_of(signer),
          proposal_index: context.index_of(proposal),
          program_index:  context.index_of(program_id)
        )
      end
    end
  end
end
