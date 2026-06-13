# frozen_string_literal: true

module Solace
  module Composers
    # Composes an `addSpendingLimitAsAuthority` instruction for the Squads
    # Smart Account program.
    #
    # Creates a SpendingLimit PDA granting designated signers a pre-authorized
    # allowance from a vault. Only the account's settings authority may do
    # this — single signature, no consensus.
    #
    # Required params:
    #   :settings           [#to_s]          Base58 address of the settings account.
    #   :settings_authority [#to_s, Keypair] The account's settings authority (must sign).
    #   :spending_limit     [#to_s]          The SpendingLimit PDA to create — derive via
    #                                        Programs::SquadsSmartAccount.get_spending_limit_address.
    #   :rent_payer         [#to_s, Keypair] Funds the new account's rent (must sign).
    #   :seed               [#to_s]          The pubkey the spending_limit PDA was derived with.
    #   :amount             [Integer]        Amount spendable per period (mint decimals).
    #   :period             [Integer]        Period enum value (reset cadence).
    #   :signers            [Array<#to_s>]   Pubkeys allowed to use the limit.
    #
    # Optional params:
    #   :account_index [Integer]      Vault index the limit spends from (default: 0).
    #   :mint          [#to_s]        Token mint (default: DEFAULT_PUBKEY = SOL).
    #   :destinations  [Array<#to_s>] Allowed destinations; empty = any (default: []).
    #   :expiration    [Integer]      Unix expiration timestamp (default: I64_MAX = never).
    #   :memo          [String]       Indexing memo (default: nil).
    class SquadsSmartAccountsAddSpendingLimitAsAuthorityComposer < Base
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

      # Extracts the rent payer address from the params
      #
      # @return [String] The rent payer address
      def rent_payer
        params[:rent_payer].to_s
      end

      # Extracts the PDA seed pubkey from the params
      #
      # @return [String] The seed pubkey
      def seed
        params[:seed].to_s
      end

      # Extracts the vault index from the params
      #
      # @return [Integer] The vault index (defaults to 0)
      def account_index
        params[:account_index] || 0
      end

      # Extracts the mint from the params
      #
      # @return [String] The mint address (defaults to DEFAULT_PUBKEY = SOL)
      def mint
        (params[:mint] || SquadsSmartAccounts::DEFAULT_PUBKEY).to_s
      end

      # Extracts the per-period amount from the params
      #
      # @return [Integer] The amount spendable per period
      def amount
        params[:amount]
      end

      # Extracts the reset period from the params
      #
      # @return [Integer] The Period enum value
      def period
        params[:period]
      end

      # Extracts the allowed signer pubkeys from the params
      #
      # @return [Array<String>] The allowed signer addresses
      def signers
        params[:signers].map(&:to_s)
      end

      # Extracts the allowed destinations from the params
      #
      # @return [Array<String>] The allowed destination addresses (defaults to [])
      def destinations
        (params[:destinations] || []).map(&:to_s)
      end

      # Extracts the expiration from the params
      #
      # @return [Integer] Unix expiration timestamp (defaults to I64_MAX = never)
      def expiration
        params[:expiration] || SquadsSmartAccounts::I64_MAX
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
        account_context.add_readonly_nonsigner(settings)
        account_context.add_readonly_signer(settings_authority)
        account_context.add_writable_nonsigner(spending_limit)
        account_context.add_writable_signer(rent_payer)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::AddSpendingLimitAsAuthorityInstruction.build(
          seed:,
          account_index:,
          mint:,
          amount:,
          period:,
          signers:,
          destinations:,
          expiration:,
          memo:,
          settings_index:           context.index_of(settings),
          settings_authority_index: context.index_of(settings_authority),
          spending_limit_index:     context.index_of(spending_limit),
          rent_payer_index:         context.index_of(rent_payer),
          system_program_index:     context.index_of(system_program),
          program_index:            context.index_of(program_id)
        )
      end
    end
  end
end
