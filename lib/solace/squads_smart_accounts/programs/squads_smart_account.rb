# frozen_string_literal: true

module Solace
  module Programs
    # Client for interacting with the Squads Smart Account program.
    #
    # This client provides methods for interacting with the Squads Smart Account
    # program, including deriving the program's PDAs. Address derivation is the
    # Program layer's responsibility — composers receive resolved addresses.
    #
    # @example Derive the settings address for the next smart account
    #   program_config = program.get_program_config
    #
    #   settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
    #     settings_seed: program_config.smart_account_index + 1
    #   )
    #
    # @see Solace::SquadsSmartAccounts
    class SquadsSmartAccount < Base
      class << self
        # Gets the address of the settings PDA for a given settings seed.
        #
        # The seed is encoded as a 16-byte little-endian u128, matching the
        # on-chain derivation ["smart_account", "settings", seed.to_le_bytes()].
        #
        # @param settings_seed [Integer] ProgramConfig#smart_account_index + 1 at composition time.
        # @return [Array<String, Integer>] The settings address and bump seed.
        def get_settings_address(settings_seed:)
          Solace::Utils::PDA.find_program_address(
            ['smart_account', 'settings', Solace::Utils::Codecs.encode_le_u128(settings_seed).bytes],
            Solace::SquadsSmartAccounts::PROGRAM_ID
          )
        end

        # Gets the address of a smart account (vault) PDA controlled by a settings account.
        #
        # Funds live in vault PDAs; one settings account controls up to 256 vaults
        # (index 0-255). The on-chain derivation is
        # ["smart_account", settings_pda, "smart_account", account_index.to_le_bytes()].
        #
        # @param settings_address [String] Base58 address of the settings account.
        # @param account_index [Integer] Vault index in range 0..255 (default: 0).
        # @return [Array<String, Integer>] The vault address and bump seed.
        def get_smart_account_address(settings_address:, account_index: 0)
          Solace::Utils::PDA.find_program_address(
            ['smart_account', settings_address, 'smart_account', [account_index]],
            Solace::SquadsSmartAccounts::PROGRAM_ID
          )
        end
      end

      # Initializes a new Squads Smart Account client.
      #
      # @param connection [Solace::Connection] The connection to the Solana cluster.
      def initialize(connection:)
        super(connection:, program_id: Solace::SquadsSmartAccounts::PROGRAM_ID)
      end

      # Alias method for get_settings_address
      #
      # @param options [Hash] A hash of options for the get_settings_address class method
      # @return [Array<String, Integer>] The settings address and bump seed.
      def get_settings_address(**options)
        self.class.get_settings_address(**options)
      end

      # Alias method for get_smart_account_address
      #
      # @param options [Hash] A hash of options for the get_smart_account_address class method
      # @return [Array<String, Integer>] The vault address and bump seed.
      def get_smart_account_address(**options)
        self.class.get_smart_account_address(**options)
      end

      # Fetches and deserializes the global ProgramConfig account from the chain.
      #
      # @return [SquadsSmartAccounts::ProgramConfig] The deserialized config.
      # @raise [RuntimeError] If the account does not exist at the expected address.
      def get_program_config
        account = connection.get_account_info(Solace::SquadsSmartAccounts::PROGRAM_CONFIG_ADDRESS)
        raise 'ProgramConfig account not found — has the validator been bootstrapped?' unless account

        Solace::SquadsSmartAccounts::ProgramConfig.deserialize(
          Solace::Utils::Codecs.base64_to_bytestream(account['data'][0])
        )
      end

      # Fetches and deserializes a Settings account from the chain.
      #
      # @param settings_address [String] Base58 address of the settings account.
      # @return [SquadsSmartAccounts::Settings] The deserialized settings.
      # @raise [RuntimeError] If the account does not exist at the given address.
      def get_settings(settings_address:)
        account = connection.get_account_info(settings_address)
        raise "Settings account not found at #{settings_address}" unless account

        Solace::SquadsSmartAccounts::Settings.deserialize(
          Solace::Utils::Codecs.base64_to_bytestream(account['data'][0])
        )
      end

      # Gets the full deterministic identity of the next smart account to be
      # created: the settings seed, settings address, and default vault address.
      #
      # This is the one-stop call for clients — persist all three values, then
      # pass the settings_seed to {#create_smart_account}. Subject to races if
      # other smart accounts are created between this call and execution — the
      # transaction fails in that case rather than creating an account at an
      # unexpected address.
      #
      # @return [SquadsSmartAccounts::SmartAccountIdentity] The next smart account's identity.
      def next_smart_account
        settings_seed = get_program_config.smart_account_index + 1

        settings_address, = get_settings_address(settings_seed:)
        smart_account_address, = get_smart_account_address(settings_address:)

        Solace::SquadsSmartAccounts::SmartAccountIdentity.new(
          settings_seed:,
          settings_address:,
          smart_account_address:
        )
      end

      # Creates a new smart account, signs it, and (optionally) sends it.
      #
      # @example Create a smart account, retaining the values to index
      #   identity = program.next_smart_account
      #
      #   tx = program.create_smart_account(
      #     payer: creator,
      #     settings_seed: identity.settings_seed,
      #     creator: creator,
      #     threshold: 1,
      #     signers: [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
      #   )
      #
      # @param payer [Keypair] The keypair that will pay for fees, rent, and the creation fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_create_smart_account}.
      # @return [Transaction] The created or sent transaction.
      def create_smart_account(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_create_smart_account(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:creator])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a new smart account transaction.
      #
      # The settings PDA is derived from the given settings_seed, which the
      # caller obtains via {#next_settings_seed} — keeping the seed explicit so
      # clients can derive and persist the settings and vault addresses before
      # sending the transaction.
      #
      # @param settings_seed [Integer] The seed for the settings PDA (see {#next_settings_seed}).
      # @param creator [#to_s, Keypair] The account creating the smart account (must sign).
      # @param threshold [Integer] Number of approvals required to execute a transaction.
      # @param signers [Array<SquadsSmartAccounts::SmartAccountSigner>] Signers on the smart account.
      # @param time_lock [Integer] (Optional) Seconds between proposal and execution (default: 0).
      # @param settings_authority [#to_s] (Optional) Pubkey of the reconfiguration authority.
      # @param rent_collector [#to_s] (Optional) Pubkey for reclaiming rent on closed accounts.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_create_smart_account(
        settings_seed:,
        creator:,
        threshold:,
        signers:,
        time_lock: 0,
        settings_authority: nil,
        rent_collector: nil,
        memo: nil
      )
        program_config = get_program_config

        settings_address, = get_settings_address(settings_seed:)

        create_smart_account_ix = Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
          creator:,
          treasury:           program_config.treasury,
          settings:           settings_address,
          threshold:,
          signers:,
          time_lock:,
          settings_authority:,
          rent_collector:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(create_smart_account_ix)
      end

      # Synchronously executes inner instructions signed by a smart account
      # (vault) PDA, signs with all co-signers, and (optionally) sends it.
      #
      # The transaction must carry enough co-signer signatures to reach the
      # settings threshold, so :signers must be Keypairs when sign is true.
      #
      # @example Transfer SOL out of a vault (1-of-1 smart account)
      #   tx = program.execute_transaction_sync(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     smart_account: identity.smart_account_address,
      #     signers: [creator],
      #     instructions: [
      #       Solace::Composers::SystemProgramTransferComposer.new(
      #         from: identity.smart_account_address, to: recipient, lamports: 1_000_000
      #       )
      #     ]
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_execute_transaction_sync}.
      # @return [Transaction] The created or sent transaction.
      def execute_transaction_sync(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_execute_transaction_sync(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, *composer_opts[:signers])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a synchronous transaction execution.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param smart_account [#to_s] Base58 address of the vault PDA the inner
      #   instructions spend from.
      # @param signers [Array<#to_s, Keypair>] Co-signers proving threshold consensus.
      # @param instructions [Array<Composers::Base>] Inner instruction composers.
      # @param account_index [Integer] (Optional) Vault index (default: 0).
      # @return [TransactionComposer] A composer with required instructions.
      def compose_execute_transaction_sync(
        settings:,
        smart_account:,
        signers:,
        instructions:,
        account_index: 0
      )
        execute_transaction_sync_ix = Composers::SquadsSmartAccountsExecuteTransactionSyncComposer.new(
          settings:,
          smart_account:,
          signers:,
          instructions:,
          account_index:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(execute_transaction_sync_ix)
      end

      # Adds a new signer to a controlled smart account, signs with the settings
      # authority, and (optionally) sends it.
      #
      # @example Add a vote-only signer
      #   tx = program.add_signer_as_authority(
      #     payer: authority,
      #     settings: identity.settings_address,
      #     settings_authority: authority,
      #     rent_payer: authority,
      #     new_signer: SmartAccountSigner.new(pubkey: new_key.address, permission: Permissions::VOTE)
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_add_signer_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def add_signer_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_add_signer_as_authority(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:settings_authority], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares an add-signer-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The account's settings authority.
      # @param rent_payer [#to_s, Keypair] Pays for settings account reallocation.
      # @param new_signer [SquadsSmartAccounts::SmartAccountSigner] The signer to add.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_add_signer_as_authority(
        settings:,
        settings_authority:,
        rent_payer:,
        new_signer:,
        memo: nil
      )
        add_signer_ix = Composers::SquadsSmartAccountsAddSignerAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          rent_payer:,
          new_signer:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(add_signer_ix)
      end

      # Removes a signer from a controlled smart account, signs with the settings
      # authority, and (optionally) sends it.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_remove_signer_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def remove_signer_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_remove_signer_as_authority(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:settings_authority], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a remove-signer-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The account's settings authority.
      # @param rent_payer [#to_s, Keypair] Pays for settings account reallocation.
      # @param old_signer [#to_s] Base58 pubkey of the signer to remove.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_remove_signer_as_authority(
        settings:,
        settings_authority:,
        rent_payer:,
        old_signer:,
        memo: nil
      )
        remove_signer_ix = Composers::SquadsSmartAccountsRemoveSignerAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          rent_payer:,
          old_signer:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(remove_signer_ix)
      end
    end
  end
end
