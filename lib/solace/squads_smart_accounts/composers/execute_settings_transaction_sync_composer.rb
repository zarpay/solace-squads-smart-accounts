# frozen_string_literal: true

module Solace
  module Composers
    # Composes an `executeSettingsTransactionSync` instruction for the Squads
    # Smart Account program.
    #
    # Synchronously applies a batch of SettingsActions to an autonomous smart
    # account. The outer transaction must be co-signed by enough smart account
    # signers to reach the settings threshold — controlled accounts are rejected
    # by the program (use the *AsAuthority composers instead).
    #
    # Required params:
    #   :settings   [String]                 Base58 address of the settings account.
    #   :signers    [Array<#to_s, Keypair>]  Co-signers proving threshold consensus.
    #   :actions    [Array<SquadsSmartAccounts::SettingsAction>] Actions applied atomically.
    #   :rent_payer [#to_s, Keypair]         Pays for settings reallocation (must sign).
    #
    # Optional params:
    #   :spending_limit_accounts [Array<#to_s>] SpendingLimit PDAs initialized or
    #                            closed by AddSpendingLimit/RemoveSpendingLimit
    #                            actions, in action order (default: []).
    #   :memo [String] Indexing memo (default: nil).
    class SquadsSmartAccountsExecuteSettingsTransactionSyncComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the co-signer addresses from the params
      #
      # @return [Array<String>] The signer addresses
      def signers
        params[:signers].map(&:to_s)
      end

      # Extracts the settings actions from the params
      #
      # @return [Array<SquadsSmartAccounts::SettingsAction>] The actions to apply
      def actions
        params[:actions]
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

      # Extracts the memo from the params
      #
      # @return [String, nil] The memo
      def memo
        params[:memo]
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
        account_context.add_writable_nonsigner(settings)
        account_context.add_writable_signer(rent_payer)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)

        # Co-signers proving threshold consensus (remaining accounts)
        signers.each { |signer| account_context.add_readonly_signer(signer) }

        # SpendingLimit PDAs initialized/closed by the actions follow the signers
        spending_limit_accounts.each { |account| account_context.add_writable_nonsigner(account) }
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::ExecuteSettingsTransactionSyncInstruction.build(
          num_signers:            signers.length,
          actions:,
          memo:,
          settings_index:         context.index_of(settings),
          rent_payer_index:       context.index_of(rent_payer),
          system_program_index:   context.index_of(system_program),
          program_index:          context.index_of(program_id),
          signer_indices:         signers.map { |signer| context.index_of(signer) },
          spending_limit_indices: spending_limit_accounts.map { |account| context.index_of(account) }
        )
      end
    end
  end
end
