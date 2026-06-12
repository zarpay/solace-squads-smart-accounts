# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `setNewSettingsAuthorityAsAuthority` instruction for the Squads
    # Smart Account program.
    #
    # Hands the settings authority of a controlled smart account to a new key.
    # Only the current settings authority may do this — single signature, no consensus.
    #
    # Required params:
    #   :settings               [String]         Base58 address of the settings account.
    #   :settings_authority     [#to_s, Keypair] The current settings authority (must sign).
    #   :rent_payer             [#to_s, Keypair] Pays for settings account reallocation (must sign).
    #   :new_settings_authority [#to_s, nil]     Base58 pubkey of the new settings authority, or
    #                                            nil to renounce control — the program convention
    #                                            stores Pubkey::default(), permanently converting
    #                                            the account to autonomous.
    #
    # Optional params:
    #   :memo [String] Indexing memo (default: nil).
    class SquadsSmartAccountsSetNewSettingsAuthorityAsAuthorityComposer < Base
      # Extracts the settings address from the params
      #
      # @return [String] The settings address
      def settings
        params[:settings].to_s
      end

      # Extracts the current settings authority address from the params
      #
      # @return [String] The current settings authority address
      def settings_authority
        params[:settings_authority].to_s
      end

      # Extracts the rent payer address from the params
      #
      # @return [String] The rent payer address
      def rent_payer
        params[:rent_payer].to_s
      end

      # Extracts the new settings authority address from the params. A nil
      # param renounces control: the program convention stores Pubkey::default(),
      # permanently converting the account to autonomous.
      #
      # @return [String] The new settings authority address
      def new_settings_authority
        (params[:new_settings_authority] || SquadsSmartAccounts::DEFAULT_PUBKEY).to_s
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
        account_context.add_readonly_signer(settings_authority)
        account_context.add_writable_signer(rent_payer)
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::SetNewSettingsAuthorityAsAuthorityInstruction.build(
          new_settings_authority:,
          memo:,
          settings_index:           context.index_of(settings),
          settings_authority_index: context.index_of(settings_authority),
          rent_payer_index:         context.index_of(rent_payer),
          system_program_index:     context.index_of(system_program),
          program_index:            context.index_of(program_id)
        )
      end
    end
  end
end
