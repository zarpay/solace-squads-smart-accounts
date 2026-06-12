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
            ['smart_account', settings_address.to_s, 'smart_account', [account_index]],
            Solace::SquadsSmartAccounts::PROGRAM_ID
          )
        end

        # Gets the address of a SpendingLimit PDA.
        #
        # The on-chain derivation is
        # ["smart_account", settings_pda, "spending_limit", seed_pubkey] — the
        # seed is an arbitrary client-generated pubkey that uniquely identifies
        # the limit under its settings account.
        #
        # @param settings_address [#to_s] Base58 address of the settings account.
        # @param seed [#to_s] The pubkey the limit is (or will be) seeded with.
        # @return [Array<String, Integer>] The spending limit address and bump seed.
        def get_spending_limit_address(settings_address:, seed:)
          Solace::Utils::PDA.find_program_address(
            ['smart_account', settings_address.to_s, 'spending_limit', seed.to_s],
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

      # Alias method for get_spending_limit_address
      #
      # @param options [Hash] A hash of options for the get_spending_limit_address class method
      # @return [Array<String, Integer>] The spending limit address and bump seed.
      def get_spending_limit_address(**options)
        self.class.get_spending_limit_address(**options)
      end

      # Fetches and deserializes a SpendingLimit account from the chain.
      #
      # @param spending_limit_address [#to_s] Base58 address of the spending limit account.
      # @return [SquadsSmartAccounts::SpendingLimit] The deserialized spending limit.
      # @raise [RuntimeError] If the account does not exist at the given address.
      def get_spending_limit(spending_limit_address:)
        account = connection.get_account_info(spending_limit_address.to_s)
        raise "SpendingLimit account not found at #{spending_limit_address}" unless account

        Solace::SquadsSmartAccounts::SpendingLimit.deserialize(
          Solace::Utils::Codecs.base64_to_bytestream(account['data'][0])
        )
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

      # Changes the approval threshold of a controlled smart account, signs with
      # the settings authority, and (optionally) sends it.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_change_threshold_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def change_threshold_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_change_threshold_as_authority(**composer_opts)

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

      # Prepares a change-threshold-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The account's settings authority.
      # @param rent_payer [#to_s, Keypair] Pays for settings account reallocation.
      # @param new_threshold [Integer] The new approval threshold.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_change_threshold_as_authority(
        settings:,
        settings_authority:,
        rent_payer:,
        new_threshold:,
        memo: nil
      )
        change_threshold_ix = Composers::SquadsSmartAccountsChangeThresholdAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          rent_payer:,
          new_threshold:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(change_threshold_ix)
      end

      # Sets the time lock of a controlled smart account, signs with the
      # settings authority, and (optionally) sends it.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_set_time_lock_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def set_time_lock_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_set_time_lock_as_authority(**composer_opts)

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

      # Prepares a set-time-lock-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The account's settings authority.
      # @param rent_payer [#to_s, Keypair] Pays for settings account reallocation.
      # @param time_lock [Integer] Seconds between approval and execution.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_set_time_lock_as_authority(
        settings:,
        settings_authority:,
        rent_payer:,
        time_lock:,
        memo: nil
      )
        set_time_lock_ix = Composers::SquadsSmartAccountsSetTimeLockAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          rent_payer:,
          time_lock:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(set_time_lock_ix)
      end

      # Hands the settings authority of a controlled smart account to a new key,
      # signs with the current settings authority, and (optionally) sends it.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_set_new_settings_authority_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def set_new_settings_authority_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_set_new_settings_authority_as_authority(**composer_opts)

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

      # Prepares a set-new-settings-authority-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The current settings authority.
      # @param rent_payer [#to_s, Keypair] Pays for settings account reallocation.
      # @param new_settings_authority [#to_s, nil] Base58 pubkey of the new settings
      #   authority, or nil to renounce control — stores Pubkey::default(), permanently
      #   converting the account to autonomous.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_set_new_settings_authority_as_authority(
        settings:,
        settings_authority:,
        rent_payer:,
        new_settings_authority:,
        memo: nil
      )
        set_new_authority_ix = Composers::SquadsSmartAccountsSetNewSettingsAuthorityAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          rent_payer:,
          new_settings_authority:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(set_new_authority_ix)
      end

      # Synchronously applies a batch of SettingsActions to an autonomous smart
      # account, signs with all co-signers, and (optionally) sends it.
      #
      # The transaction must carry enough co-signer signatures to reach the
      # settings threshold, so :signers must be Keypairs when sign is true.
      # Controlled accounts are rejected by the program — use the *AsAuthority
      # methods instead.
      #
      # @example Atomically add a signer and raise the threshold (1-of-1 account)
      #   tx = program.execute_settings_transaction_sync(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     signers: [creator],
      #     rent_payer: creator,
      #     actions: [
      #       SettingsAction.add_signer(pubkey: new_key, permission: Permissions::ALL),
      #       SettingsAction.change_threshold(2)
      #     ]
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_execute_settings_transaction_sync}.
      # @return [Transaction] The created or sent transaction.
      def execute_settings_transaction_sync(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_execute_settings_transaction_sync(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, *composer_opts[:signers], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a synchronous settings transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signers [Array<#to_s, Keypair>] Co-signers proving threshold consensus.
      # @param actions [Array<SquadsSmartAccounts::SettingsAction>] Actions applied atomically.
      # @param rent_payer [#to_s, Keypair] Pays for settings reallocation.
      # @param spending_limit_accounts [Array<#to_s>] (Optional) SpendingLimit PDAs
      #   initialized or closed by spending-limit actions, in action order.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_execute_settings_transaction_sync(
        settings:,
        signers:,
        actions:,
        rent_payer:,
        spending_limit_accounts: [],
        memo: nil
      )
        settings_sync_ix = Composers::SquadsSmartAccountsExecuteSettingsTransactionSyncComposer.new(
          settings:,
          signers:,
          actions:,
          rent_payer:,
          spending_limit_accounts:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(settings_sync_ix)
      end

      # Creates a spending limit on a controlled smart account, signs with the
      # settings authority, and (optionally) sends it.
      #
      # @example Grant a member a daily SOL allowance
      #   spending_limit, = program.get_spending_limit_address(
      #     settings_address: identity.settings_address, seed:
      #   )
      #
      #   tx = program.add_spending_limit_as_authority(
      #     payer: authority,
      #     settings: identity.settings_address,
      #     settings_authority: authority,
      #     rent_payer: authority,
      #     spending_limit:,
      #     seed:,
      #     amount: 500_000_000,
      #     period: Period::DAY,
      #     signers: [member.address]
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_add_spending_limit_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def add_spending_limit_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_add_spending_limit_as_authority(**composer_opts)

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

      # Prepares an add-spending-limit-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The account's settings authority.
      # @param spending_limit [#to_s] The SpendingLimit PDA to create.
      # @param rent_payer [#to_s, Keypair] Funds the new account's rent.
      # @param seed [#to_s] The pubkey the spending_limit PDA was derived with.
      # @param amount [Integer] Amount spendable per period (mint decimals).
      # @param period [Integer] Period enum value (reset cadence).
      # @param signers [Array<#to_s>] Pubkeys allowed to use the limit.
      # @param account_index [Integer] (Optional) Vault index (default: 0).
      # @param mint [#to_s] (Optional) Token mint (default: DEFAULT_PUBKEY = SOL).
      # @param destinations [Array<#to_s>] (Optional) Allowed destinations; empty = any.
      # @param expiration [Integer] (Optional) Unix expiration (default: I64_MAX = never).
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_add_spending_limit_as_authority(
        settings:,
        settings_authority:,
        spending_limit:,
        rent_payer:,
        seed:,
        amount:,
        period:,
        signers:,
        account_index: 0,
        mint: Solace::SquadsSmartAccounts::DEFAULT_PUBKEY,
        destinations: [],
        expiration: Solace::SquadsSmartAccounts::I64_MAX,
        memo: nil
      )
        add_spending_limit_ix = Composers::SquadsSmartAccountsAddSpendingLimitAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          spending_limit:,
          rent_payer:,
          seed:,
          amount:,
          period:,
          signers:,
          account_index:,
          mint:,
          destinations:,
          expiration:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(add_spending_limit_ix)
      end

      # Transfers SOL from a vault within a pre-authorized spending limit,
      # signs with the allowed signer, and (optionally) sends it.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_use_spending_limit}.
      # @return [Transaction] The created or sent transaction.
      def use_spending_limit(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_use_spending_limit(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:signer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a use-spending-limit transaction (SOL limits only for now).
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] An allowed signer of the spending limit.
      # @param spending_limit [#to_s] The SpendingLimit PDA to spend against.
      # @param smart_account [#to_s] The vault to transfer from.
      # @param destination [#to_s] The destination account.
      # @param amount [Integer] Lamports to transfer.
      # @param decimals [Integer] (Optional) Mint decimals, 9 for SOL (default: 9).
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_use_spending_limit(
        settings:,
        signer:,
        spending_limit:,
        smart_account:,
        destination:,
        amount:,
        decimals: 9,
        memo: nil
      )
        use_spending_limit_ix = Composers::SquadsSmartAccountsUseSpendingLimitComposer.new(
          settings:,
          signer:,
          spending_limit:,
          smart_account:,
          destination:,
          amount:,
          decimals:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(use_spending_limit_ix)
      end

      # Removes a spending limit from a controlled smart account, signs with the
      # settings authority, and (optionally) sends it. The closed account's rent
      # is refunded to the rent collector.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_remove_spending_limit_as_authority}.
      # @return [Transaction] The created or sent transaction.
      def remove_spending_limit_as_authority(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_remove_spending_limit_as_authority(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:settings_authority])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a remove-spending-limit-as-authority transaction.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param settings_authority [#to_s, Keypair] The account's settings authority.
      # @param spending_limit [#to_s] The SpendingLimit PDA to close.
      # @param rent_collector [#to_s] Receives the closed account's rent (does not sign).
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_remove_spending_limit_as_authority(
        settings:,
        settings_authority:,
        spending_limit:,
        rent_collector:,
        memo: nil
      )
        remove_spending_limit_ix = Composers::SquadsSmartAccountsRemoveSpendingLimitAsAuthorityComposer.new(
          settings:,
          settings_authority:,
          spending_limit:,
          rent_collector:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(remove_spending_limit_ix)
      end
    end
  end
end
