# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `createProposal` instruction for the Squads Smart Account program.
    #
    # Creates the Proposal account that tracks votes for a stored Transaction.
    # The transaction must already exist (its index is referenced here).
    #
    # Required params:
    #   :settings          [#to_s]          Base58 address of the settings account.
    #   :proposal          [#to_s]          The Proposal PDA to create.
    #   :creator           [#to_s, Keypair] A smart-account signer creating the proposal (must sign).
    #   :rent_payer        [#to_s, Keypair] Funds the new account's rent (must sign).
    #   :transaction_index [Integer]        Index of the transaction this proposal tracks.
    #
    # Optional params:
    #   :draft [Boolean] Initialize as Draft instead of Active (default: false).
    class SquadsSmartAccountsCreateProposalComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the proposal PDA address from the params
      #
      # @return [String] The proposal address
      def proposal
        params[:proposal].to_s
      end

      # Extracts the creator address from the params
      #
      # @return [String] The creator address
      def creator
        params[:creator].to_s
      end

      # Extracts the rent payer address from the params
      #
      # @return [String] The rent payer address
      def rent_payer
        params[:rent_payer].to_s
      end

      # Extracts the transaction index from the params
      #
      # @return [Integer] The transaction index the proposal tracks
      def transaction_index
        params[:transaction_index]
      end

      # Extracts the draft flag from the params
      #
      # @return [Boolean] Whether to initialize the proposal as Draft (defaults to false)
      def draft
        params[:draft] || false
      end

      # Returns the Squads Smart Account program id from the constants
      #
      # @return [String] The Squads Smart Account program id
      def program_id
        SquadsSmartAccounts::PROGRAM_ID
      end

      # Returns the system program id from the constants
      #
      # @return [String] The system program id
      def system_program
        Solace::Constants::SYSTEM_PROGRAM_ID
      end

      # Declares all accounts required by this instruction.
      def setup_accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_writable_nonsigner(proposal)
        account_context.add_readonly_signer(creator)
        account_context.add_writable_signer(rent_payer)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::CreateProposalInstruction.build(
          transaction_index:,
          draft:,
          settings_index:       context.index_of(settings),
          proposal_index:       context.index_of(proposal),
          creator_index:        context.index_of(creator),
          rent_payer_index:     context.index_of(rent_payer),
          system_program_index: context.index_of(system_program),
          program_index:        context.index_of(program_id)
        )
      end
    end
  end
end
