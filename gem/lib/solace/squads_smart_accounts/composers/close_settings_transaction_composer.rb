# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `closeSettingsTransaction` instruction for the Squads Smart
    # Account program.
    #
    # Closes a SettingsTransaction and its Proposal, refunding rent to the
    # respective collectors. No smart-account signer is required — only the fee
    # payer signs. The transaction is closeable once its proposal is terminal
    # (Executed/Rejected/Cancelled) or stale.
    #
    # Required params:
    #   :settings                   [#to_s] Base58 address of the settings account.
    #   :proposal                   [#to_s] The Proposal PDA to close.
    #   :transaction                [#to_s] The SettingsTransaction PDA to close.
    #   :proposal_rent_collector    [#to_s] Receives the proposal rent.
    #   :transaction_rent_collector [#to_s] Receives the transaction rent (must equal
    #                                       transaction.rent_collector).
    class SquadsSmartAccountsCloseSettingsTransactionComposer < Base
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

      # Extracts the settings transaction PDA address from the params
      #
      # @return [String] The transaction address
      def transaction
        params[:transaction].to_s
      end

      # Extracts the proposal rent collector address from the params
      #
      # @return [String] The proposal rent collector address
      def proposal_rent_collector
        params[:proposal_rent_collector].to_s
      end

      # Extracts the transaction rent collector address from the params
      #
      # @return [String] The transaction rent collector address
      def transaction_rent_collector
        params[:transaction_rent_collector].to_s
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
        account_context.add_writable_nonsigner(transaction)
        account_context.add_writable_nonsigner(proposal_rent_collector)
        account_context.add_writable_nonsigner(transaction_rent_collector)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::CloseSettingsTransactionInstruction.build(
          settings_index:                   context.index_of(settings),
          proposal_index:                   context.index_of(proposal),
          transaction_index:                context.index_of(transaction),
          proposal_rent_collector_index:    context.index_of(proposal_rent_collector),
          transaction_rent_collector_index: context.index_of(transaction_rent_collector),
          system_program_index:             context.index_of(system_program),
          program_index:                    context.index_of(program_id)
        )
      end
    end
  end
end
