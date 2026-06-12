# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `useSpendingLimit` instruction for the Squads Smart Account program.
    #
    # Transfers SOL from a vault to a destination within a pre-authorized
    # spending limit — single signature from an allowed signer, no consensus.
    #
    # NOTE: SOL limits only for now. The four SPL-only optional accounts (mint,
    # both token accounts, token program) are filled with the Squads program ID,
    # which is Anchor's convention for an absent optional account. SPL support
    # will parameterize those four slots.
    #
    # Required params:
    #   :settings       [#to_s]          Base58 address of the settings account.
    #   :signer         [#to_s, Keypair] An allowed signer of the spending limit (must sign).
    #   :spending_limit [#to_s]          The SpendingLimit PDA to spend against.
    #   :smart_account  [#to_s]          The vault to transfer from.
    #   :destination    [#to_s]          The destination account.
    #   :amount         [Integer]        Lamports to transfer.
    #
    # Optional params:
    #   :decimals [Integer] Mint decimals, 9 for SOL (default: 9).
    #   :memo     [String]  Indexing memo (default: nil).
    class SquadsSmartAccountsUseSpendingLimitComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the allowed signer address from the params
      #
      # @return [String] The signer address
      def signer
        params[:signer].to_s
      end

      # Extracts the spending limit PDA address from the params
      #
      # @return [String] The spending limit address
      def spending_limit
        params[:spending_limit].to_s
      end

      # Extracts the vault address from the params
      #
      # @return [String] The vault (smart account) address
      def smart_account
        params[:smart_account].to_s
      end

      # Extracts the destination address from the params
      #
      # @return [String] The destination address
      def destination
        params[:destination].to_s
      end

      # Extracts the transfer amount from the params
      #
      # @return [Integer] Lamports to transfer
      def amount
        params[:amount]
      end

      # Extracts the mint decimals from the params
      #
      # @return [Integer] The mint decimals (defaults to 9 for SOL)
      def decimals
        params[:decimals] || 9
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
      #
      # The four SPL-only optional slots resolve to the Squads program account
      # (already declared readonly), so no extra declarations are needed for them.
      def setup_accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_readonly_signer(signer)
        account_context.add_writable_nonsigner(spending_limit)
        account_context.add_writable_nonsigner(smart_account)
        account_context.add_writable_nonsigner(destination)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # The SPL-only optional slots (mint, token accounts, token program) carry
      # the program account's index — Anchor's absent-optional convention.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        absent = context.index_of(program_id)

        SquadsSmartAccounts::Instructions::UseSpendingLimitInstruction.build(
          amount:,
          decimals:,
          memo:,
          settings_index:                    context.index_of(settings),
          signer_index:                      context.index_of(signer),
          spending_limit_index:              context.index_of(spending_limit),
          smart_account_index:               context.index_of(smart_account),
          destination_index:                 context.index_of(destination),
          system_program_index:              context.index_of(system_program),
          mint_index:                        absent,
          smart_account_token_account_index: absent,
          destination_token_account_index:   absent,
          token_program_index:               absent,
          program_index:                     absent
        )
      end
    end
  end
end
