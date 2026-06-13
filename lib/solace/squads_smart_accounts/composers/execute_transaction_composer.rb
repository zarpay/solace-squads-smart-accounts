# frozen_string_literal: true

module Solace
  module Composers
    # Composes an `executeTransaction` instruction for the Squads Smart Account program.
    #
    # Executes the inner instructions of an Approved proposal's stored
    # Transaction. The stored message's account metas are appended as remaining
    # accounts in their canonical order. The vault (smart account) PDA is the
    # message's signer but cannot sign the outer transaction — the program signs
    # it via CPI — so it is forced to a non-signer here, mirroring
    # {SquadsSmartAccountsExecuteTransactionSyncComposer}.
    #
    # Required params:
    #   :settings      [#to_s]          Base58 address of the settings account.
    #   :proposal      [#to_s]          The Proposal PDA (must be Approved).
    #   :transaction   [#to_s]          The Transaction PDA to execute.
    #   :signer        [#to_s, Keypair] The executing signer (must sign; needs Execute permission).
    #   :smart_account [#to_s]          The vault PDA the message spends from (forced non-signer).
    #   :account_metas [Array<Hash>]    The stored message's account metas, in order —
    #     each { pubkey: #to_s, signer: Boolean, writable: Boolean } (Transaction#account_metas).
    class SquadsSmartAccountsExecuteTransactionComposer < Base
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

      # Extracts the transaction PDA address from the params
      #
      # @return [String] The transaction address
      def transaction
        params[:transaction].to_s
      end

      # Extracts the executing signer address from the params
      #
      # @return [String] The signer address
      def signer
        params[:signer].to_s
      end

      # Extracts the vault (smart account) address from the params
      #
      # @return [String] The vault address
      def smart_account
        params[:smart_account].to_s
      end

      # The ordered stored-message account metas (from Transaction#account_metas),
      # whose pubkeys are already base58 strings and flags already booleans.
      #
      # @return [Array<Hash>] Each { pubkey: String, signer: Boolean, writable: Boolean }
      def account_metas
        params[:account_metas]
      end

      # Returns the Squads Smart Account program id from the constants
      #
      # @return [String] The Squads Smart Account program id
      def program_id
        SquadsSmartAccounts::PROGRAM_ID
      end

      # Declares all accounts required by this instruction: the fixed accounts
      # followed by each stored-message account with its flags.
      def setup_accounts
        account_context.add_writable_nonsigner(settings)
        account_context.add_writable_nonsigner(proposal)
        account_context.add_readonly_nonsigner(transaction)
        account_context.add_readonly_signer(signer)
        account_context.add_readonly_nonsigner(program_id)

        account_metas.each { |meta| add_remaining_account(meta) }
      end

      # Builds the instruction with resolved account indices. The remaining
      # account indices preserve the stored message's account_keys order.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::ExecuteTransactionInstruction.build(
          settings_index:            context.index_of(settings),
          proposal_index:            context.index_of(proposal),
          transaction_index:         context.index_of(transaction),
          signer_index:              context.index_of(signer),
          program_index:             context.index_of(program_id),
          remaining_account_indices: account_metas.map { |meta| context.index_of(meta[:pubkey]) }
        )
      end

      private

      # Declares one stored-message account with its flags — except the vault,
      # whose signer bit is forced off (the program signs the vault PDA via CPI
      # during execution, so it must not sign the outer transaction).
      #
      # @param meta [Hash] A { pubkey:, signer:, writable: } account meta.
      # @return [void]
      def add_remaining_account(meta)
        pubkey   = meta[:pubkey]
        signer   = pubkey == smart_account ? false : meta[:signer]
        writable = meta[:writable]

        if signer && writable then account_context.add_writable_signer(pubkey)
        elsif signer          then account_context.add_readonly_signer(pubkey)
        elsif writable        then account_context.add_writable_nonsigner(pubkey)
        else account_context.add_readonly_nonsigner(pubkey)
        end
      end
    end
  end
end
