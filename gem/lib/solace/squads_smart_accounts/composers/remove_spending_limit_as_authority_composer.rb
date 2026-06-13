# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `removeSpendingLimitAsAuthority` instruction for the Squads
    # Smart Account program.
    #
    # Closes a SpendingLimit PDA, refunding its rent to the rent collector.
    # Only the account's settings authority may do this — single signature,
    # no consensus.
    #
    # Required params:
    #   :settings           [#to_s]          Base58 address of the settings account.
    #   :settings_authority [#to_s, Keypair] The account's settings authority (must sign).
    #   :spending_limit     [#to_s]          The SpendingLimit PDA to close.
    #   :rent_collector     [#to_s]          Receives the closed account's rent (does not sign).
    #
    # Optional params:
    #   :memo [String] Indexing memo (default: nil).
    class SquadsSmartAccountsRemoveSpendingLimitAsAuthorityComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the settings authority address from the params
      #
      # @return [String] The settings authority address
      def settings_authority
        params[:settings_authority].to_s
      end

      # Extracts the spending limit PDA address from the params
      #
      # @return [String] The spending limit address
      def spending_limit
        params[:spending_limit].to_s
      end

      # Extracts the rent collector address from the params
      #
      # @return [String] The rent collector address
      def rent_collector
        params[:rent_collector].to_s
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

      # Declares all accounts required by this instruction.
      def setup_accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_readonly_signer(settings_authority)
        account_context.add_writable_nonsigner(spending_limit)
        account_context.add_writable_nonsigner(rent_collector)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::RemoveSpendingLimitAsAuthorityInstruction.build(
          memo:,
          settings_index:           context.index_of(settings),
          settings_authority_index: context.index_of(settings_authority),
          spending_limit_index:     context.index_of(spending_limit),
          rent_collector_index:     context.index_of(rent_collector),
          program_index:            context.index_of(program_id)
        )
      end
    end
  end
end
