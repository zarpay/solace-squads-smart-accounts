# frozen_string_literal: true

module Solace
  module Composers
    # Composes an `executeTransactionSync` instruction for the Squads Smart Account program.
    #
    # Synchronously executes inner instructions signed by a smart account (vault)
    # PDA. The outer transaction must be co-signed by enough smart account signers
    # to reach the settings threshold — no proposal/voting lifecycle is involved.
    #
    # Inner instructions are regular Solace composers (e.g.
    # SystemProgramTransferComposer with the vault as :from). Their account
    # requirements are merged into this composer's context, and their built
    # instructions are re-encoded into the Squads compiled wire format.
    #
    # Required params:
    #   :settings      [String]  Base58 address of the settings account.
    #   :smart_account [String]  Base58 address of the vault PDA the inner
    #                            instructions spend from — derive via
    #                            Programs::SquadsSmartAccount.get_smart_account_address.
    #   :signers       [Array<String>] Base58 pubkeys co-signing the outer transaction.
    #                            Must be exactly enough to reach the threshold.
    #   :instructions  [Array<Solace::Composers::Base>] Inner instruction composers.
    #
    # Optional params:
    #   :account_index [Integer] Vault index the smart_account was derived with (default: 0).
    class SquadsSmartAccountsExecuteTransactionSyncComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the vault address from the params
      #
      # @return [String] The vault (smart account) address
      def smart_account
        params[:smart_account].to_s
      end

      # Extracts the co-signer addresses from the params
      #
      # @return [Array<String>] The signer addresses
      def signers
        params[:signers].map(&:to_s)
      end

      # Extracts the inner instruction composers from the params
      #
      # @return [Array<Solace::Composers::Base>] The inner instruction composers
      def instructions
        params[:instructions]
      end

      # Extracts the vault index from the params
      #
      # @return [Integer] The vault index (defaults to 0)
      def account_index
        params[:account_index] || 0
      end

      # Returns the Squads Smart Account program id from the constants
      #
      # @return [String] The Squads Smart Account program id
      def program_id
        SquadsSmartAccounts::PROGRAM_ID
      end

      # Ordered, unique pubkeys referenced by the inner instructions, in
      # declaration order, excluding co-signers (which already occupy the
      # leading remaining-account positions).
      #
      # @return [Array<String>] The remaining account pubkeys
      def remaining_pubkeys
        @remaining_pubkeys ||= instructions.flat_map do |composer|
          composer.account_context.pubkey_account_map.keys
        end.uniq - signers
      end

      # Local AccountContext scoped to the full remaining-accounts list as the
      # program sees it: co-signers first, then the inner-instruction accounts.
      # The deployed program resolves inner instruction indexes against this
      # full list (signers included) — not a post-signer slice.
      #
      # @return [Solace::Utils::AccountContext] The remaining-accounts context
      def remaining_accounts_context
        @remaining_accounts_context ||= Solace::Utils::AccountContext.new.tap do |context|
          context.accounts = signers + remaining_pubkeys
        end
      end

      # Inner instructions built against the remaining-accounts context, ready
      # for encoding into the Squads compiled wire format.
      #
      # @return [Array<Solace::Instruction>] The compiled inner instructions
      def compiled_instructions
        @compiled_instructions ||= instructions.map do |composer|
          composer.build_instruction(remaining_accounts_context)
        end
      end

      # Declares all accounts required by this instruction.
      def setup_accounts
        # Required read-only accounts
        account_context.add_readonly_nonsigner(settings)
        account_context.add_readonly_nonsigner(program_id)

        # Co-signers proving threshold consensus
        signers.each { |signer| account_context.add_readonly_signer(signer) }

        # Accounts referenced by the inner instructions, with their inner flags —
        # except the vault, which must not sign the outer transaction (the
        # program patches its signer bit at runtime during the CPI).
        instructions.each do |composer|
          composer.account_context.pubkey_account_map.each do |pubkey, flags|
            signer   = pubkey == smart_account ? false : flags[:signer]
            writable = flags[:writable]

            if signer && writable then account_context.add_writable_signer(pubkey)
            elsif signer          then account_context.add_readonly_signer(pubkey)
            elsif writable        then account_context.add_writable_nonsigner(pubkey)
            else account_context.add_readonly_nonsigner(pubkey)
            end
          end
        end
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::ExecuteTransactionSyncInstruction.build(
          account_index:             account_index,
          num_signers:               signers.length,
          instructions:              compiled_instructions,
          settings_index:            context.index_of(settings),
          program_index:             context.index_of(program_id),
          signer_indices:            signers.map { |signer| context.index_of(signer) },
          remaining_account_indices: remaining_pubkeys.map { |pubkey| context.index_of(pubkey) }
        )
      end
    end
  end
end
