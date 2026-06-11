# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `createSmartAccount` instruction for the Squads Smart Account program.
    #
    # Required params:
    #   :creator   [String]                        Base58 pubkey of the account creating the smart account.
    #   :treasury  [String]                        Base58 pubkey of the treasury (from ProgramConfig).
    #   :threshold [Integer]                       Number of approvals required to execute a transaction.
    #   :signers   [Array<SquadsSmartAccounts::SmartAccountSigner>]  Signers on the smart account.
    #   :time_lock [Integer]                       Seconds between proposal and execution (0 to disable).
    #
    # Optional params:
    #   :settings_authority [String]  Pubkey of the reconfiguration authority (default: nil).
    #   :rent_collector     [String]  Pubkey for reclaiming rent on closed accounts (default: nil).
    #   :memo               [String]  Indexing memo (default: nil).
    class SquadsSmartAccountsCreateSmartAccountComposer < Base
      # Returns the on-chain address of the settings PDA that will be created.
      # Derived from seeds ["smart_account", "settings", creator_pubkey].
      #
      # @return [String] Base58 address of the settings account.
      def settings_address
        @settings_address ||= Solace::Utils::PDA.find_program_address(
          ['smart_account', 'settings', params[:creator].to_s],
          SquadsSmartAccounts::PROGRAM_ID
        ).first
      end

      # Declares all accounts required by this instruction.
      def setup_accounts
        account_context.add_writable_nonsigner(SquadsSmartAccounts::PROGRAM_CONFIG_ADDRESS)
        account_context.add_writable_nonsigner(params[:treasury].to_s)
        account_context.add_writable_signer(params[:creator].to_s)
        account_context.add_readonly_nonsigner(Solace::Constants::SYSTEM_PROGRAM_ID)
        account_context.add_readonly_nonsigner(SquadsSmartAccounts::PROGRAM_ID)
        # settings is the PDA to be created, passed as a remaining account.
        account_context.add_writable_nonsigner(settings_address)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::CreateSmartAccountInstruction.build(
          settings_authority:   params[:settings_authority],
          threshold:            params[:threshold],
          signers:              params[:signers],
          time_lock:            params[:time_lock],
          rent_collector:       params[:rent_collector],
          memo:                 params[:memo],
          program_config_index: context.index_of(SquadsSmartAccounts::PROGRAM_CONFIG_ADDRESS),
          treasury_index:       context.index_of(params[:treasury].to_s),
          creator_index:        context.index_of(params[:creator].to_s),
          system_program_index: context.index_of(Solace::Constants::SYSTEM_PROGRAM_ID),
          program_index:        context.index_of(SquadsSmartAccounts::PROGRAM_ID),
          settings_index:       context.index_of(settings_address)
        )
      end
    end
  end
end
