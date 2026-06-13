# frozen_string_literal: true

module Solace
  module Composers
    # Composes an `executeSettingsTransaction` instruction for the Squads Smart
    # Account program.
    #
    # Applies the stored SettingsActions of an Approved proposal's
    # SettingsTransaction to the settings account. SpendingLimit PDAs touched by
    # AddSpendingLimit / RemoveSpendingLimit actions are appended as remaining
    # accounts in action order.
    #
    # Required params:
    #   :settings    [#to_s]          Base58 address of the settings account.
    #   :signer      [#to_s, Keypair] The executing signer (must sign; needs Execute permission).
    #   :proposal    [#to_s]          The Proposal PDA (must be Approved).
    #   :transaction [#to_s]          The SettingsTransaction PDA to apply.
    #   :rent_payer  [#to_s, Keypair] Pays for any settings realloc (must sign).
    #
    # Optional params:
    #   :spending_limit_accounts [Array<#to_s>] SpendingLimit PDAs initialized or
    #                            closed by the actions, in action order (default: []).
    class SquadsSmartAccountsExecuteSettingsTransactionComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the executing signer address from the params
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

      # Extracts the settings transaction PDA address from the params
      #
      # @return [String] The transaction address
      def transaction
        params[:transaction].to_s
      end

      # Extracts the rent payer address from the params
      #
      # @return [String] The rent payer address
      def rent_payer
        params[:rent_payer].to_s
      end

      # Extracts the spending limit PDAs touched by the actions from the params
      #
      # @return [Array<String>] The spending limit addresses (defaults to [])
      def spending_limit_accounts
        (params[:spending_limit_accounts] || []).map(&:to_s)
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
      def setup_accounts # rubocop:disable Metrics/AbcSize
        account_context.add_writable_nonsigner(settings)
        account_context.add_readonly_signer(signer)
        account_context.add_writable_nonsigner(proposal)
        account_context.add_readonly_nonsigner(transaction)
        account_context.add_writable_signer(rent_payer)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)

        # SpendingLimit PDAs initialized/closed by the actions, in action order.
        spending_limit_accounts.each { |account| account_context.add_writable_nonsigner(account) }
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::ExecuteSettingsTransactionInstruction.build(
          settings_index:         context.index_of(settings),
          signer_index:           context.index_of(signer),
          proposal_index:         context.index_of(proposal),
          transaction_index:      context.index_of(transaction),
          rent_payer_index:       context.index_of(rent_payer),
          system_program_index:   context.index_of(system_program),
          program_index:          context.index_of(program_id),
          spending_limit_indices: spending_limit_accounts.map { |account| context.index_of(account) }
        )
      end
    end
  end
end
