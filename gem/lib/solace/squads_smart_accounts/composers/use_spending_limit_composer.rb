# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `useSpendingLimit` instruction for the Squads Smart Account program.
    #
    # Transfers from a vault to a destination within a pre-authorized spending
    # limit — single signature from an allowed signer, no consensus. Supports
    # both SOL limits and SPL Token / Token-2022 limits.
    #
    # For SOL limits (no :mint), the four SPL-only optional accounts (mint, both
    # token accounts, token program) are filled with the Squads program ID,
    # Anchor's convention for an absent optional account. For token limits, those
    # four slots carry the real accounts; the program transfers via
    # `transfer_checked`, so :decimals must match the mint.
    #
    # Required params:
    #   :settings       [#to_s]          Base58 address of the settings account.
    #   :signer         [#to_s, Keypair] An allowed signer of the spending limit (must sign).
    #   :spending_limit [#to_s]          The SpendingLimit PDA to spend against.
    #   :smart_account  [#to_s]          The vault to transfer from.
    #   :destination    [#to_s]          The destination owner (receives SOL, or owns the destination ATA).
    #   :amount         [Integer]        Amount to transfer (mint decimals).
    #
    # Optional params (SOL):
    #   :decimals [Integer] Mint decimals, 9 for SOL (default: 9).
    #   :memo     [String]  Indexing memo (default: nil).
    #
    # Optional params (token limits — all four required together):
    #   :mint                        [#to_s] The token mint (omit for SOL).
    #   :token_program               [#to_s] The program owning the mint.
    #   :smart_account_token_account [#to_s] The vault's ATA for the mint.
    #   :destination_token_account   [#to_s] The destination owner's ATA (must already exist).
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

      # Extracts the token mint from the params
      #
      # @return [String, nil] The mint address, or nil for a SOL limit
      def mint
        params[:mint]&.to_s
      end

      # Extracts the token program from the params
      #
      # @return [String, nil] The token program address (token limits only)
      def token_program
        params[:token_program]&.to_s
      end

      # Extracts the vault's token account from the params
      #
      # @return [String, nil] The vault ATA address (token limits only)
      def smart_account_token_account
        params[:smart_account_token_account]&.to_s
      end

      # Extracts the destination's token account from the params
      #
      # @return [String, nil] The destination ATA address (token limits only)
      def destination_token_account
        params[:destination_token_account]&.to_s
      end

      # Whether this is a SOL spending limit. True when no mint is given or the
      # mint is the default pubkey — the same marker the program uses for SOL.
      #
      # @return [Boolean]
      def sol?
        mint.nil? || mint.to_s == SquadsSmartAccounts::DEFAULT_PUBKEY
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
      # For SOL limits the four SPL-only optional slots resolve to the Squads
      # program account (already declared readonly), so no extra declarations
      # are needed. For token limits the real token accounts are declared.
      #
      # rubocop:disable Metrics/AbcSize -- straight enumeration of up to 11 accounts
      def setup_accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_readonly_signer(signer)
        account_context.add_writable_nonsigner(spending_limit)
        account_context.add_writable_nonsigner(smart_account)
        account_context.add_writable_nonsigner(destination)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)

        return if sol?

        account_context.add_readonly_nonsigner(mint)
        account_context.add_writable_nonsigner(smart_account_token_account)
        account_context.add_writable_nonsigner(destination_token_account)
        account_context.add_readonly_nonsigner(token_program)
      end
      # rubocop:enable Metrics/AbcSize

      # Builds the instruction with resolved account indices.
      #
      # For SOL limits the SPL-only optional slots (mint, token accounts, token
      # program) carry the program account's index — Anchor's absent-optional
      # convention. For token limits they carry the real account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      #
      # rubocop:disable Metrics/AbcSize -- straight index resolution of up to 11 accounts
      def build_instruction(context)
        program_index = context.index_of(program_id)

        # Anchor signals an absent optional account by passing the program's own
        # account in that slot; for SOL limits all four token slots are absent.
        absent = program_index

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
          mint_index:                        sol? ? absent : context.index_of(mint),
          smart_account_token_account_index: sol? ? absent : context.index_of(smart_account_token_account),
          destination_token_account_index:   sol? ? absent : context.index_of(destination_token_account),
          token_program_index:               sol? ? absent : context.index_of(token_program),
          program_index:
        )
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
