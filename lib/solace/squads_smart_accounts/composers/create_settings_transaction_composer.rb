# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `createSettingsTransaction` instruction for the Squads Smart
    # Account program.
    #
    # Stores a batch of SettingsActions as a SettingsTransaction for later
    # approval and execution. Autonomous accounts only.
    #
    # Required params:
    #   :settings    [#to_s]          Base58 address of the settings account.
    #   :transaction [#to_s]          The SettingsTransaction PDA to create.
    #   :creator     [#to_s, Keypair] A signer creating the transaction (must sign).
    #   :rent_payer  [#to_s, Keypair] Funds the new account's rent (must sign).
    #   :actions     [Array<SquadsSmartAccounts::SettingsAction>] Actions to store.
    #
    # Optional params:
    #   :memo [String] Indexing memo (default: nil).
    class SquadsSmartAccountsCreateSettingsTransactionComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the transaction PDA address from the params
      #
      # @return [String] The transaction address
      def transaction
        params[:transaction].to_s
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

      # Extracts the settings actions from the params
      #
      # @return [Array<SquadsSmartAccounts::SettingsAction>] The actions to store
      def actions
        params[:actions]
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
        account_context.add_writable_nonsigner(transaction)
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
        SquadsSmartAccounts::Instructions::CreateSettingsTransactionInstruction.build(
          actions:,
          memo:,
          settings_index:       context.index_of(settings),
          transaction_index:    context.index_of(transaction),
          creator_index:        context.index_of(creator),
          rent_payer_index:     context.index_of(rent_payer),
          system_program_index: context.index_of(system_program),
          program_index:        context.index_of(program_id)
        )
      end
    end
  end
end
