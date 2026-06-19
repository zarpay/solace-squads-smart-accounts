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
      # Default number of candidate settings PDAs offered by windowed creation.
      # The on-chain counter must land inside this window for the transaction to
      # succeed; ~20 absorbs heavy concurrency while staying well under the
      # transaction account limit. Non-winning candidates are never initialized,
      # so a larger window costs transaction size only, never rent.
      DEFAULT_CREATION_WINDOW = 20

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

        # Gets the address of a Transaction PDA.
        #
        # The on-chain derivation is
        # ["smart_account", settings_pda, "transaction", u64(transaction_index)].
        #
        # @param settings_address [#to_s] Base58 address of the settings account.
        # @param transaction_index [Integer] The transaction index (settings.transaction_index + 1 for a new one).
        # @return [Array<String, Integer>] The transaction address and bump seed.
        def get_transaction_address(settings_address:, transaction_index:)
          Solace::Utils::PDA.find_program_address(
            ['smart_account', settings_address.to_s, 'transaction',
             Solace::Utils::Codecs.encode_le_u64(transaction_index).bytes],
            Solace::SquadsSmartAccounts::PROGRAM_ID
          )
        end

        # Gets the address of a Proposal PDA.
        #
        # The on-chain derivation appends a trailing "proposal" marker to the
        # transaction seeds:
        # ["smart_account", settings_pda, "transaction", u64(transaction_index), "proposal"].
        #
        # @param settings_address [#to_s] Base58 address of the settings account.
        # @param transaction_index [Integer] The transaction index the proposal tracks.
        # @return [Array<String, Integer>] The proposal address and bump seed.
        def get_proposal_address(settings_address:, transaction_index:)
          Solace::Utils::PDA.find_program_address(
            ['smart_account', settings_address.to_s, 'transaction',
             Solace::Utils::Codecs.encode_le_u64(transaction_index).bytes, 'proposal'],
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

      # Alias method for get_transaction_address
      #
      # @param options [Hash] A hash of options for the get_transaction_address class method
      # @return [Array<String, Integer>] The transaction address and bump seed.
      def get_transaction_address(**options)
        self.class.get_transaction_address(**options)
      end

      # Alias method for get_proposal_address
      #
      # @param options [Hash] A hash of options for the get_proposal_address class method
      # @return [Array<String, Integer>] The proposal address and bump seed.
      def get_proposal_address(**options)
        self.class.get_proposal_address(**options)
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

      # Fetches and deserializes a Transaction account from the chain.
      #
      # @param transaction_address [#to_s] Base58 address of the transaction account.
      # @return [SquadsSmartAccounts::Transaction] The deserialized transaction.
      # @raise [RuntimeError] If the account does not exist at the given address.
      def get_transaction(transaction_address:)
        account = connection.get_account_info(transaction_address.to_s)
        raise "Transaction account not found at #{transaction_address}" unless account

        Solace::SquadsSmartAccounts::Transaction.deserialize(
          Solace::Utils::Codecs.base64_to_bytestream(account['data'][0])
        )
      end

      # Fetches and deserializes a SettingsTransaction account from the chain.
      #
      # @param transaction_address [#to_s] Base58 address of the settings transaction account.
      # @return [SquadsSmartAccounts::SettingsTransaction] The deserialized settings transaction.
      # @raise [RuntimeError] If the account does not exist at the given address.
      def get_settings_transaction(transaction_address:)
        account = connection.get_account_info(transaction_address.to_s)
        raise "SettingsTransaction account not found at #{transaction_address}" unless account

        Solace::SquadsSmartAccounts::SettingsTransaction.deserialize(
          Solace::Utils::Codecs.base64_to_bytestream(account['data'][0])
        )
      end

      # Fetches and deserializes a Proposal account from the chain.
      #
      # @param proposal_address [#to_s] Base58 address of the proposal account.
      # @return [SquadsSmartAccounts::Proposal] The deserialized proposal.
      # @raise [RuntimeError] If the account does not exist at the given address.
      def get_proposal(proposal_address:)
        account = connection.get_account_info(proposal_address.to_s)
        raise "Proposal account not found at #{proposal_address}" unless account

        Solace::SquadsSmartAccounts::Proposal.deserialize(
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

      # Fetches a confirmed createSmartAccount transaction and deserializes the
      # CreateSmartAccountEvent it emitted, revealing the settings address the
      # program actually created.
      #
      # This is how a windowed creation (see {#compose_create_smart_account} with
      # `window > 1`) learns which candidate won: the program picks one of the
      # offered PDAs, observable only after the transaction lands. Match the
      # returned `new_settings_pubkey` against your {#next_smart_account_candidates}
      # to recover the seed and vault.
      #
      # @param signature [String] Signature of the confirmed createSmartAccount transaction.
      # @return [SquadsSmartAccounts::CreateSmartAccountEvent] The deserialized event.
      # @raise [RuntimeError] If the transaction is missing or carries no logEvent.
      def get_created_smart_account_event(signature:)
        transaction = connection.get_transaction(
          signature,
          commitment:                     'confirmed',
          encoding:                       'json',
          maxSupportedTransactionVersion: 0
        )
        raise "Transaction not found for signature #{signature}" unless transaction

        io = log_event_stream(transaction)
        raise "No logEvent inner instruction found in transaction #{signature}" unless io

        args = Solace::SquadsSmartAccounts::LogEventArgsV2.deserialize(io)

        Solace::SquadsSmartAccounts::CreateSmartAccountEvent.deserialize(StringIO.new(args.event))
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

        settings_address,      = get_settings_address(settings_seed:)
        smart_account_address, = get_smart_account_address(settings_address:)

        Solace::SquadsSmartAccounts::SmartAccountIdentity.new(
          settings_seed:,
          settings_address:,
          smart_account_address:
        )
      end

      # Gets a window of candidate identities for race-free creation: the next
      # `count` consecutive smart accounts (seeds `index+1 .. index+count`).
      #
      # Pass the candidates' settings addresses to {#create_smart_account_windowed},
      # which offers them all and lets the program pick whichever matches the
      # freshly incremented counter — so creation succeeds even if other accounts
      # are created concurrently, as long as the true index lands in the window.
      #
      # @param count [Integer] Size of the candidate window (default: {DEFAULT_CREATION_WINDOW}).
      # @return [Array<SquadsSmartAccounts::SmartAccountIdentity>] Candidate identities, in seed order.
      def next_smart_account_candidates(count: DEFAULT_CREATION_WINDOW)
        start_seed = get_program_config.smart_account_index + 1

        Array.new(count) do |offset|
          settings_seed = start_seed + offset

          settings_address,      = get_settings_address(settings_seed:)
          smart_account_address, = get_smart_account_address(settings_address:)

          Solace::SquadsSmartAccounts::SmartAccountIdentity.new(
            settings_seed:,
            settings_address:,
            smart_account_address:
          )
        end
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
      # With the default `window: 1` this offers a single settings PDA and is
      # subject to the same races as {#next_smart_account}. Pass `window > 1` to
      # offer a window of consecutive candidate PDAs (seeds `settings_seed ..
      # settings_seed + window - 1`); the program initializes whichever matches the
      # freshly incremented counter, so creation tolerates concurrent creations.
      # The chosen address is then resolved via {#get_created_smart_account_event}.
      #
      # @param settings_seed [Integer] The (starting) seed for the settings PDA (see {#next_settings_seed}).
      # @param creator [#to_s, Keypair] The account creating the smart account (must sign).
      # @param threshold [Integer] Number of approvals required to execute a transaction.
      # @param signers [Array<SquadsSmartAccounts::SmartAccountSigner>] Signers on the smart account.
      # @param window [Integer] (Optional) Number of candidate PDAs to offer (default: 1).
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
        window: 1,
        time_lock: 0,
        settings_authority: nil,
        rent_collector: nil,
        memo: nil
      )
        program_config = get_program_config

        settings = Array.new(window) do |offset|
          address, = get_settings_address(settings_seed: settings_seed + offset)
          address
        end

        create_smart_account_ix = Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
          creator:,
          treasury:           program_config.treasury,
          settings:,
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

      # Prepares a use-spending-limit transaction.
      #
      # For SOL limits, omit :mint. For SPL Token / Token-2022 limits, pass
      # :mint and :token_program; the vault and destination ATAs are derived
      # here from those plus :smart_account and :destination (the owners). The
      # destination ATA must already exist on-chain — this method does not
      # create it. Pass :decimals matching the mint (9 for SOL).
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] An allowed signer of the spending limit.
      # @param spending_limit [#to_s] The SpendingLimit PDA to spend against.
      # @param smart_account [#to_s] The vault to transfer from.
      # @param destination [#to_s] The destination owner (receives SOL, or owns the destination ATA).
      # @param amount [Integer] Amount to transfer (mint decimals).
      # @param decimals [Integer] (Optional) Mint decimals, 9 for SOL (default: 9).
      # @param mint [#to_s] (Optional) Token mint; omit for SOL limits.
      # @param token_program [#to_s] (Optional) Program owning the mint; required with :mint.
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
        mint: nil,
        token_program: nil,
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
          mint:,
          token_program:,
          memo:,
          # Additional options are required when the non SOL tokens are being spent
          **token_account_options(
            smart_account:,
            destination:,
            mint:,
            token_program:
          )
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

      # Creates a pending vault transaction from inner instructions, signs it,
      # and (optionally) sends it. The transaction is stored, not executed — it
      # awaits a proposal and approvals (see the proposal flow).
      #
      # @example Store a vault → recipient transfer for later approval
      #   tx = program.create_transaction(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     creator: creator,
      #     rent_payer: creator,
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
      # @param composer_opts [Hash] Options for {#compose_create_transaction}.
      # @return [Transaction] The created or sent transaction.
      def create_transaction(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_create_transaction(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:creator], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a create-transaction transaction. The transaction index is the
      # settings account's current transaction_index + 1, and the Transaction PDA
      # is derived from it here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param creator [#to_s, Keypair] The transaction creator (must sign).
      # @param rent_payer [#to_s, Keypair] Funds the new account's rent.
      # @param instructions [Array<Composers::Base>] Inner instruction composers.
      # @param account_index [Integer] (Optional) Vault index (default: 0).
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_create_transaction(
        settings:,
        creator:,
        rent_payer:,
        instructions:,
        account_index: 0,
        memo: nil
      )
        transaction_index = get_settings(settings_address: settings.to_s).transaction_index + 1
        transaction,      = get_transaction_address(settings_address: settings.to_s, transaction_index:)

        create_transaction_ix = Composers::SquadsSmartAccountsCreateTransactionComposer.new(
          settings:,
          transaction:,
          creator:,
          rent_payer:,
          instructions:,
          account_index:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(create_transaction_ix)
      end

      # Creates a proposal for a stored transaction, signs it, and (optionally)
      # sends it. A proposal created with the default `draft: false` starts
      # Active (ready to vote); `draft: true` starts Draft and must be activated.
      #
      # @example Open voting on the transaction just created
      #   tx = program.create_proposal(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     creator: creator,
      #     rent_payer: creator,
      #     transaction_index: 1
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_create_proposal}.
      # @return [Transaction] The created or sent transaction.
      def create_proposal(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_create_proposal(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:creator], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a create-proposal transaction. The Proposal PDA is derived from
      # the settings address and transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param creator [#to_s, Keypair] A smart-account signer creating the proposal (must sign).
      # @param rent_payer [#to_s, Keypair] Funds the new account's rent.
      # @param transaction_index [Integer] Index of the transaction this proposal tracks.
      # @param draft [Boolean] (Optional) Initialize as Draft instead of Active (default: false).
      # @return [TransactionComposer] A composer with required instructions.
      def compose_create_proposal(
        settings:,
        creator:,
        rent_payer:,
        transaction_index:,
        draft: false
      )
        proposal, = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        create_proposal_ix = Composers::SquadsSmartAccountsCreateProposalComposer.new(
          settings:,
          proposal:,
          creator:,
          rent_payer:,
          transaction_index:,
          draft:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(create_proposal_ix)
      end

      # Approves a proposal on behalf of a signer, signs it, and (optionally)
      # sends it. The signer must be a smart-account member with the Vote
      # permission; the proposal becomes Approved once approvals reach threshold.
      #
      # @example Approve the proposal for transaction index 1
      #   tx = program.approve_proposal(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     signer: creator,
      #     transaction_index: 1
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_approve_proposal}.
      # @return [Transaction] The created or sent transaction.
      def approve_proposal(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_approve_proposal(**composer_opts)

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

      # Prepares an approve-proposal transaction. The Proposal PDA is derived
      # from the settings address and transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] The voting signer (must sign).
      # @param transaction_index [Integer] Index of the transaction the proposal tracks.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_approve_proposal(
        settings:,
        signer:,
        transaction_index:,
        memo: nil
      )
        proposal, = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        approve_proposal_ix = Composers::SquadsSmartAccountsApproveProposalComposer.new(
          settings:,
          signer:,
          proposal:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(approve_proposal_ix)
      end

      # Rejects a proposal on behalf of a signer, signs it, and (optionally)
      # sends it. The signer must be a smart-account member with the Vote
      # permission; the proposal becomes Rejected once rejections reach the cutoff.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_reject_proposal}.
      # @return [Transaction] The created or sent transaction.
      def reject_proposal(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_reject_proposal(**composer_opts)

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

      # Prepares a reject-proposal transaction. The Proposal PDA is derived from
      # the settings address and transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] The voting signer (must sign).
      # @param transaction_index [Integer] Index of the transaction the proposal tracks.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_reject_proposal(
        settings:,
        signer:,
        transaction_index:,
        memo: nil
      )
        proposal, = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        reject_proposal_ix = Composers::SquadsSmartAccountsRejectProposalComposer.new(
          settings:,
          signer:,
          proposal:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(reject_proposal_ix)
      end

      # Cancels an Approved proposal on behalf of a signer, signs it, and
      # (optionally) sends it. The signer must be a smart-account member with the
      # Vote permission; once cancellations reach the threshold the proposal
      # becomes Cancelled and its transaction can no longer execute.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_cancel_proposal}.
      # @return [Transaction] The created or sent transaction.
      def cancel_proposal(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_cancel_proposal(**composer_opts)

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

      # Prepares a cancel-proposal transaction. The Proposal PDA is derived from
      # the settings address and transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] The voting signer (must sign).
      # @param transaction_index [Integer] Index of the transaction the proposal tracks.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_cancel_proposal(
        settings:,
        signer:,
        transaction_index:,
        memo: nil
      )
        proposal, = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        cancel_proposal_ix = Composers::SquadsSmartAccountsCancelProposalComposer.new(
          settings:,
          signer:,
          proposal:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(cancel_proposal_ix)
      end

      # Activates a draft proposal (Draft → Active), signs it, and (optionally)
      # sends it. The signer must be a smart-account member with the Initiate
      # permission. Only needed for proposals created with `draft: true`.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_activate_proposal}.
      # @return [Transaction] The created or sent transaction.
      def activate_proposal(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_activate_proposal(**composer_opts)

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

      # Prepares an activate-proposal transaction. The Proposal PDA is derived
      # from the settings address and transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] The activating signer (must sign).
      # @param transaction_index [Integer] Index of the transaction the proposal tracks.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_activate_proposal(
        settings:,
        signer:,
        transaction_index:
      )
        proposal, = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        activate_proposal_ix = Composers::SquadsSmartAccountsActivateProposalComposer.new(
          settings:,
          signer:,
          proposal:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(activate_proposal_ix)
      end

      # Executes an Approved proposal's stored transaction, signs it, and
      # (optionally) sends it — moving the vault funds. The signer must be a
      # smart-account member with the Execute permission, and the proposal must
      # be Approved with its time lock elapsed.
      #
      # @example Execute the approved transaction at index 1
      #   tx = program.execute_transaction(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     signer: creator,
      #     transaction_index: 1
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_execute_transaction}.
      # @return [Transaction] The created or sent transaction.
      def execute_transaction(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_execute_transaction(**composer_opts)

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

      # Prepares an execute-transaction transaction. Fetches the stored
      # Transaction to derive its vault and replay its account metas as the
      # instruction's remaining accounts; the Transaction and Proposal PDAs are
      # derived from the settings address and transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] The executing signer (must sign).
      # @param transaction_index [Integer] Index of the transaction to execute.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_execute_transaction(
        settings:,
        signer:,
        transaction_index:
      )
        transaction_address, = get_transaction_address(settings_address: settings.to_s, transaction_index:)
        proposal_address,    = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        transaction = get_transaction(transaction_address:)

        smart_account, = get_smart_account_address(
          settings_address: settings.to_s,
          account_index:    transaction.account_index
        )

        execute_transaction_ix = Composers::SquadsSmartAccountsExecuteTransactionComposer.new(
          settings:,
          proposal:      proposal_address,
          transaction:   transaction_address,
          signer:,
          smart_account:,
          account_metas: transaction.account_metas
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(execute_transaction_ix)
      end

      # Closes a vault transaction and its proposal, refunding their rent, signs
      # it, and (optionally) sends it. Closeable once the proposal is terminal
      # (Executed/Rejected/Cancelled) or stale and not Approved. Only the fee
      # payer signs.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_close_transaction}.
      # @return [Transaction] The created or sent transaction.
      def close_transaction(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_close_transaction(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer)

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a close-transaction transaction. The Proposal and vault
      # Transaction PDAs are derived here; the rent collectors default to the
      # on-chain stored values (the proposal's and transaction's collectors) when
      # not supplied.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param transaction_index [Integer] Index of the vault transaction to close.
      # @param proposal_rent_collector [#to_s] (Optional) Receives the proposal rent
      #   (defaults to the proposal's stored rent collector).
      # @param transaction_rent_collector [#to_s] (Optional) Receives the transaction rent
      #   (defaults to the transaction's stored rent collector).
      # @return [TransactionComposer] A composer with required instructions.
      def compose_close_transaction(
        settings:,
        transaction_index:,
        proposal_rent_collector: nil,
        transaction_rent_collector: nil
      )
        transaction, = get_transaction_address(settings_address: settings.to_s, transaction_index:)
        proposal,    = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        proposal_rent_collector    ||= get_proposal(proposal_address: proposal).rent_collector
        transaction_rent_collector ||= get_transaction(transaction_address: transaction).rent_collector

        close_transaction_ix = Composers::SquadsSmartAccountsCloseTransactionComposer.new(
          settings:,
          proposal:,
          transaction:,
          proposal_rent_collector:,
          transaction_rent_collector:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(close_transaction_ix)
      end

      # Creates a settings transaction (a stored batch of SettingsActions) on an
      # autonomous smart account, signs it, and (optionally) sends it. The
      # transaction is stored, not applied — it awaits a proposal and approvals.
      #
      # @example Store a "raise the threshold" settings change for later approval
      #   tx = program.create_settings_transaction(
      #     payer: creator,
      #     settings: identity.settings_address,
      #     creator: creator,
      #     rent_payer: creator,
      #     actions: [SettingsAction.change_threshold(2)]
      #   )
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_create_settings_transaction}.
      # @return [Transaction] The created or sent transaction.
      def create_settings_transaction(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_create_settings_transaction(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:creator], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a create-settings-transaction transaction. The transaction index
      # is the settings account's current transaction_index + 1, and the
      # SettingsTransaction PDA is derived from it here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param creator [#to_s, Keypair] A signer creating the transaction (must sign).
      # @param rent_payer [#to_s, Keypair] Funds the new account's rent.
      # @param actions [Array<SquadsSmartAccounts::SettingsAction>] Actions to store.
      # @param memo [String] (Optional) Indexing memo.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_create_settings_transaction(
        settings:,
        creator:,
        rent_payer:,
        actions:,
        memo: nil
      )
        transaction_index = get_settings(settings_address: settings.to_s).transaction_index + 1
        transaction,      = get_transaction_address(settings_address: settings.to_s, transaction_index:)

        create_settings_transaction_ix = Composers::SquadsSmartAccountsCreateSettingsTransactionComposer.new(
          settings:,
          transaction:,
          creator:,
          rent_payer:,
          actions:,
          memo:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(create_settings_transaction_ix)
      end

      # Applies an Approved proposal's stored settings transaction, signs it, and
      # (optionally) sends it. The signer must be a smart-account member with the
      # Execute permission, and the proposal must be Approved with its time lock
      # elapsed.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_execute_settings_transaction}.
      # @return [Transaction] The created or sent transaction.
      def execute_settings_transaction(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_execute_settings_transaction(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer, composer_opts[:signer], composer_opts[:rent_payer])

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares an execute-settings-transaction transaction. The Proposal and
      # SettingsTransaction PDAs are derived from the settings address and
      # transaction index here.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param signer [#to_s, Keypair] The executing signer (must sign).
      # @param transaction_index [Integer] Index of the settings transaction to apply.
      # @param rent_payer [#to_s, Keypair] Pays for any settings realloc (must sign).
      # @param spending_limit_accounts [Array<#to_s>] (Optional) SpendingLimit PDAs
      #   touched by the actions, in action order.
      # @return [TransactionComposer] A composer with required instructions.
      def compose_execute_settings_transaction(
        settings:,
        signer:,
        transaction_index:,
        rent_payer:,
        spending_limit_accounts: []
      )
        transaction, = get_transaction_address(settings_address: settings.to_s, transaction_index:)
        proposal,    = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        execute_settings_transaction_ix = Composers::SquadsSmartAccountsExecuteSettingsTransactionComposer.new(
          settings:,
          signer:,
          proposal:,
          transaction:,
          rent_payer:,
          spending_limit_accounts:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(execute_settings_transaction_ix)
      end

      # Closes a settings transaction and its proposal, refunding their rent,
      # signs it, and (optionally) sends it. Closeable once the proposal is
      # terminal (Executed/Rejected/Cancelled) or stale. Only the fee payer signs.
      #
      # @param payer [Keypair] The keypair that will pay the transaction fee.
      # @param sign [Boolean] Whether to sign the transaction.
      # @param execute [Boolean] Whether to execute the transaction.
      # @param composer_opts [Hash] Options for {#compose_close_settings_transaction}.
      # @return [Transaction] The created or sent transaction.
      def close_settings_transaction(
        payer:,
        sign: true,
        execute: true,
        **composer_opts
      )
        composer = compose_close_settings_transaction(**composer_opts)

        yield composer if block_given?

        tx = composer
             .set_fee_payer(payer)
             .compose_transaction

        if sign
          tx.sign(payer)

          connection.send_transaction(tx.serialize) if execute
        end

        tx
      end

      # Prepares a close-settings-transaction transaction. The Proposal and
      # SettingsTransaction PDAs are derived here; the rent collectors default to
      # the on-chain values (the proposal's and transaction's stored collectors)
      # when not supplied.
      #
      # @param settings [#to_s] Base58 address of the settings account.
      # @param transaction_index [Integer] Index of the settings transaction to close.
      # @param proposal_rent_collector [#to_s] (Optional) Receives the proposal rent
      #   (defaults to the proposal's stored rent collector).
      # @param transaction_rent_collector [#to_s] (Optional) Receives the transaction rent
      #   (defaults to the transaction's stored rent collector).
      # @return [TransactionComposer] A composer with required instructions.
      def compose_close_settings_transaction(
        settings:,
        transaction_index:,
        proposal_rent_collector: nil,
        transaction_rent_collector: nil
      )
        transaction, = get_transaction_address(settings_address: settings.to_s, transaction_index:)
        proposal,    = get_proposal_address(settings_address: settings.to_s, transaction_index:)

        proposal_rent_collector    ||= get_proposal(proposal_address: proposal).rent_collector
        transaction_rent_collector ||= get_settings_transaction(transaction_address: transaction).rent_collector

        close_settings_transaction_ix = Composers::SquadsSmartAccountsCloseSettingsTransactionComposer.new(
          settings:,
          proposal:,
          transaction:,
          proposal_rent_collector:,
          transaction_rent_collector:
        )

        TransactionComposer
          .new(connection:)
          .add_instruction(close_settings_transaction_ix)
      end

      private

      # Locates the program's `logEvent` self-CPI among a landed transaction's
      # inner instructions and returns its args as a bytestream (the instruction
      # data past the 8-byte discriminator), or nil if absent. The instruction is
      # identified by its stable discriminator, so the match is exact.
      #
      # @param transaction [Hash] The raw getTransaction result.
      # @return [StringIO, nil] Stream positioned at the start of the LogEventArgsV2.
      def log_event_stream(transaction)
        groups = transaction.dig('meta', 'innerInstructions') || []

        groups.each do |group|
          Array(group['instructions']).each do |ix|
            next if ix['data'].nil?

            binary = Solace::Utils::Codecs.base58_to_binary(ix['data'])
            next unless binary.byteslice(0, 8).bytes == Solace::SquadsSmartAccounts::LogEventArgsV2::DISCRIMINATOR

            return StringIO.new(binary.byteslice(8..))
          end
        end

        nil
      end

      # Derives the vault and destination ATAs for a token spending-limit spend.
      #
      # @param smart_account [#to_s] The vault PDA (owner of the source ATA).
      # @param destination [#to_s] The destination owner (owner of the destination ATA).
      # @param mint [#to_s] The token mint.
      # @param token_program [#to_s] The program owning the mint.
      # @return [Hash] :smart_account_token_account and :destination_token_account addresses.
      def token_account_options(smart_account:, destination:, mint:, token_program:)
        return {} if mint.nil? || mint.to_s == Solace::SquadsSmartAccounts::DEFAULT_PUBKEY

        {
          smart_account_token_account: Solace::Programs::AssociatedTokenAccount.get_address(
            owner:            smart_account.to_s,
            mint:             mint.to_s,
            token_program_id: token_program.to_s
          ).first,
          destination_token_account:   Solace::Programs::AssociatedTokenAccount.get_address(
            owner:            destination.to_s,
            mint:             mint.to_s,
            token_program_id: token_program.to_s
          ).first
        }
      end
    end
  end
end
