# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `createTransaction` instruction for the Squads Smart Account program.
    #
    # Stores a pending vault transaction on-chain. The inner instructions are
    # regular Solace composers (e.g. SystemProgramTransferComposer with the vault
    # as :from); they are compiled into a TransactionMessage — account keys ordered
    # canonically, header counts derived, instructions re-indexed — and serialized
    # into the stored transaction. Execution happens later via the proposal flow.
    #
    # Scope: simple messages only — no ephemeral signers, no address-table lookups.
    #
    # Required params:
    #   :settings     [#to_s]                 Base58 address of the settings account.
    #   :transaction  [#to_s]                 The Transaction PDA to create.
    #   :creator      [#to_s, Keypair]        The transaction creator (must sign).
    #   :rent_payer   [#to_s, Keypair]        Funds the new account's rent (must sign).
    #   :instructions [Array<Composers::Base>] Inner instruction composers.
    #
    # Optional params:
    #   :account_index     [Integer] Vault index the message spends from (default: 0).
    #   :ephemeral_signers [Integer] Ephemeral signer count (default: 0; only 0 supported).
    #   :memo              [String]  Indexing memo (default: nil).
    class SquadsSmartAccountsCreateTransactionComposer < Base
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

      # Extracts the ephemeral signer count from the params
      #
      # @return [Integer] The ephemeral signer count (defaults to 0)
      def ephemeral_signers
        params[:ephemeral_signers] || 0
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

      # Local AccountContext holding the compiled inner message: all accounts the
      # inner instructions reference, ordered canonically. Inner instruction
      # indexes resolve against this context.
      #
      # @return [Solace::Utils::AccountContext] The compiled inner-message context
      def message_context
        @message_context ||= Solace::Utils::AccountContext.new.tap do |context|
          instructions.each { |composer| context.merge_from(composer.account_context) }
          context.compile
        end
      end

      # Serializes the inner instructions into a TransactionMessage byte array.
      #
      # @return [Array<Integer>] The serialized message bytes
      def transaction_message
        header = message_context.header

        SquadsSmartAccounts::TransactionMessage.new(
          num_signers:              header[0],
          num_writable_signers:     header[0] - header[1],
          num_writable_non_signers: (message_context.accounts.length - header[0]) - header[2],
          account_keys:             message_context.accounts,
          instructions:             instructions.map { |composer| composer.build_instruction(message_context) }
        ).serialize
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
        SquadsSmartAccounts::Instructions::CreateTransactionInstruction.build(
          account_index:,
          ephemeral_signers:,
          transaction_message:,
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
