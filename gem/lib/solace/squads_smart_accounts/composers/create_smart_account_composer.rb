# frozen_string_literal: true

module Solace
  module Composers
    # Composes a `createSmartAccount` instruction for the Squads Smart Account program.
    #
    # Required params:
    #   :creator   [String]                        Base58 pubkey of the account creating the smart account.
    #   :treasury  [String]                        Base58 pubkey of the treasury (from ProgramConfig).
    #   :settings  [#to_s, Array<#to_s>]           The settings PDA(s) to offer as remaining accounts.
    #                                              Pass a single address for deterministic creation
    #                                              (derive via Programs::SquadsSmartAccount.get_settings_address),
    #                                              or an array (a "window" of candidates) for race-free creation —
    #                                              the program initializes whichever matches the incremented
    #                                              counter. See Programs::SquadsSmartAccount.next_smart_account_candidates.
    #   :threshold [Integer]                       Number of approvals required to execute a transaction.
    #   :signers   [Array<SquadsSmartAccounts::SmartAccountSigner>]  Signers on the smart account.
    #   :time_lock [Integer]                       Seconds between proposal and execution (0 to disable).
    #
    # Optional params:
    #   :settings_authority [String]  Pubkey of the reconfiguration authority (default: nil).
    #   :rent_collector     [String]  Pubkey for reclaiming rent on closed accounts (default: nil).
    #   :memo               [String]  Indexing memo (default: nil).
    class SquadsSmartAccountsCreateSmartAccountComposer < Base
      # Extracts the treasury address from the params
      #
      # @return [String] The treasury address
      def treasury
        params[:treasury].to_s
      end

      # Extracts the creator address from the params
      #
      # @return [String] The creator address
      def creator
        params[:creator].to_s
      end

      # Normalizes the :settings param to an array of base58 addresses.
      #
      # Accepts a single pubkey (deterministic creation) or an array of candidate
      # pubkeys (windowed, race-free creation), so both flows share this composer.
      #
      # @return [Array<String>] The settings address(es), in seed order.
      def settings
        Array(params[:settings]).map(&:to_s)
      end

      # Returns the program config address from the constants
      #
      # @return [String] The program config address
      def config
        SquadsSmartAccounts::PROGRAM_CONFIG_ADDRESS
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

      # Extracts the settings authority address from the params
      #
      # @return [String, nil] The settings authority address
      def settings_authority
        params[:settings_authority]&.to_s
      end

      # Extracts the rent collector address from the params
      #
      # @return [String, nil] The rent collector address
      def rent_collector
        params[:rent_collector]&.to_s
      end

      # Extracts the threshold from the params
      #
      # @return [Integer] The threshold
      def threshold
        params[:threshold]
      end

      # Extracts the time lock from the params
      #
      # @return [Integer] The time lock
      def time_lock
        params[:time_lock]
      end

      # Extracts the signers from the params
      #
      # @return [Array<SquadsSmartAccounts::SmartAccountSigner>] The signers
      def signers
        params[:signers]
      end

      # Extracts the memo from the params
      #
      # @return [String, nil] The memo
      def memo
        params[:memo]
      end

      # Declares all accounts required by this instruction.
      def setup_accounts
        # Required read-only accounts
        account_context.add_readonly_nonsigner(system_program)
        account_context.add_readonly_nonsigner(program_id)

        # Writable accounts
        account_context.add_writable_nonsigner(config)
        account_context.add_writable_nonsigner(treasury)

        # Each candidate settings PDA is offered as a writable remaining account.
        settings.each { |address| account_context.add_writable_nonsigner(address) }

        # Writable signers
        account_context.add_writable_signer(creator)
      end

      # Builds the instruction with resolved account indices.
      #
      # @param context [Solace::Utils::AccountContext] Merged context from TransactionComposer.
      # @return [Solace::Instruction]
      def build_instruction(context)
        SquadsSmartAccounts::Instructions::CreateSmartAccountInstruction.build(
          settings_authority:,
          threshold:,
          signers:,
          time_lock:,
          rent_collector:,
          memo:,
          program_config_index: context.index_of(config),
          treasury_index:       context.index_of(treasury),
          creator_index:        context.index_of(creator),
          system_program_index: context.index_of(system_program),
          program_index:        context.index_of(program_id),
          settings_index:       settings.map { |address| context.index_of(address) }
        )
      end
    end
  end
end
