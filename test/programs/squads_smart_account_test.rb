# frozen_string_literal: true

require_relative '../test_helper'

include Solace::SquadsSmartAccounts
include Solace::SquadsSmartAccounts::Test

describe Solace::Programs::SquadsSmartAccount do
  let(:klass) { Solace::Programs::SquadsSmartAccount }
  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { klass.new(connection: connection) }
  let(:creator) { Fixtures.load_keypair('creator') }

  describe '#initialize' do
    it 'assigns connection' do
      assert_equal connection, program.connection
    end

    it 'assigns the Squads Smart Account program id' do
      assert_equal Solace::SquadsSmartAccounts::PROGRAM_ID, program.program_id
    end
  end

  describe '.get_settings_address' do
    let(:settings_seed) { 42 }

    it 'derives the settings PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', 'settings', Solace::Utils::Codecs.encode_le_u128(settings_seed).bytes],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_settings_address(settings_seed: settings_seed)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'is available as an instance method' do
      assert_equal klass.get_settings_address(settings_seed: settings_seed),
                   program.get_settings_address(settings_seed: settings_seed)
    end
  end

  describe '.get_smart_account_address' do
    let(:settings_address) { klass.get_settings_address(settings_seed: 42).first }

    it 'derives the vault PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', settings_address, 'smart_account', [0]],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_smart_account_address(settings_address: settings_address)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'defaults account_index to 0' do
      assert_equal klass.get_smart_account_address(settings_address: settings_address, account_index: 0),
                   klass.get_smart_account_address(settings_address: settings_address)
    end

    it 'derives different addresses for different account indexes' do
      address_zero, = klass.get_smart_account_address(settings_address: settings_address)
      address_one,  = klass.get_smart_account_address(settings_address: settings_address, account_index: 1)

      refute_equal address_zero, address_one
    end

    it 'is available as an instance method' do
      assert_equal klass.get_smart_account_address(settings_address: settings_address),
                   program.get_smart_account_address(settings_address: settings_address)
    end
  end

  describe '#get_program_config' do
    it 'fetches and deserializes the global program config' do
      config = program.get_program_config

      assert_kind_of ProgramConfig, config
      assert_kind_of Integer, config.smart_account_index
      assert Solace::Utils::Codecs.valid_base58?(config.treasury)
    end
  end

  describe '#next_smart_account' do
    it 'returns the identity of the next smart account' do
      identity = program.next_smart_account

      assert_kind_of SmartAccountIdentity, identity
      assert_equal program.get_program_config.smart_account_index + 1, identity.settings_seed
    end
  end

  describe '#create_smart_account' do
    describe 'when the creator pays for the transaction' do
      before(:all) do
        @identity = program.next_smart_account

        @tx = program.create_smart_account(
          payer:         creator,
          settings_seed: @identity.settings_seed,
          creator:       creator,
          threshold:     1,
          signers:       [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'creates the settings account at the identity address' do
        settings = program.get_settings(settings_address: @identity.settings_address)

        assert_equal @identity.settings_seed, settings.seed
        assert_equal 1, settings.threshold
      end

      it 'increments the on-chain smart account index to the identity seed' do
        assert_equal @identity.settings_seed, program.get_program_config.smart_account_index
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      let(:payer) { Fixtures.load_keypair('payer') }

      before(:all) do
        @identity = program.next_smart_account
        @creation_fee = program.get_program_config.smart_account_creation_fee

        @payer_starting_balance   = connection.get_balance(payer.address)
        @creator_starting_balance = connection.get_balance(creator.address)

        @tx = program.create_smart_account(
          payer:         payer,
          settings_seed: @identity.settings_seed,
          creator:       creator,
          threshold:     1,
          signers:       [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings_account = connection.get_account_info(@identity.settings_address)

        @payer_ending_balance   = connection.get_balance(payer.address)
        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'creates the settings account at the identity address' do
        settings = program.get_settings(settings_address: @identity.settings_address)

        assert_equal @identity.settings_seed, settings.seed
      end

      it 'deducts only the transaction fee from the sponsor' do
        # 2 signatures (payer + creator) at 5000 lamports per signature
        assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
      end

      it 'deducts the creation fee and settings rent from the creator' do
        assert_equal @creator_starting_balance - @creation_fee - @settings_account['lamports'],
                     @creator_ending_balance
      end
    end
  end

  describe '#compose_create_smart_account' do
    it 'returns a TransactionComposer ready for a fee payer' do
      composer = program.compose_create_smart_account(
        settings_seed: program.next_smart_account.settings_seed,
        creator:       creator,
        threshold:     1,
        signers:       [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
      )

      assert_kind_of Solace::TransactionComposer, composer
    end
  end

  describe '#execute_transaction_sync' do
    let(:vault_funding)   { 1_000_000_000 }
    let(:transfer_amount) { 250_000_000 }

    describe 'when the signer pays for the transaction' do
      before(:all) do
        # Create a 1-of-1 smart account and fund its default vault.
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:   creator,
          threshold: 1,
          signers:   [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
        )

        signature = connection.request_airdrop(@identity.smart_account_address, vault_funding)
        connection.wait_for_confirmed_signature { signature['result'] }

        # Transfer SOL out of the vault through the program method.
        @recipient = Solace::Keypair.generate

        @tx = program.execute_transaction_sync(
          payer:         creator,
          settings:      @identity.settings_address,
          smart_account: @identity.smart_account_address,
          signers:       [creator],
          instructions:  [
            Solace::Composers::SystemProgramTransferComposer.new(
              from:     @identity.smart_account_address,
              to:       @recipient.address,
              lamports: transfer_amount
            )
          ]
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'transfers the amount out of the vault to the recipient' do
        assert_equal transfer_amount, connection.get_balance(@recipient.address)
        assert_equal vault_funding - transfer_amount,
                     connection.get_balance(@identity.smart_account_address)
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      let(:payer) { Fixtures.load_keypair('payer') }

      before(:all) do
        # Create a 1-of-1 smart account and fund its default vault.
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:   creator,
          threshold: 1,
          signers:   [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
        )

        signature = connection.request_airdrop(@identity.smart_account_address, vault_funding)
        connection.wait_for_confirmed_signature { signature['result'] }

        @recipient = Solace::Keypair.generate

        @payer_starting_balance   = connection.get_balance(payer.address)
        @creator_starting_balance = connection.get_balance(creator.address)

        # The sponsor pays the fee; the creator only co-signs for consensus.
        @tx = program.execute_transaction_sync(
          payer:         payer,
          settings:      @identity.settings_address,
          smart_account: @identity.smart_account_address,
          signers:       [creator],
          instructions:  [
            Solace::Composers::SystemProgramTransferComposer.new(
              from:     @identity.smart_account_address,
              to:       @recipient.address,
              lamports: transfer_amount
            )
          ]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @payer_ending_balance   = connection.get_balance(payer.address)
        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'transfers the amount out of the vault to the recipient' do
        assert_equal transfer_amount, connection.get_balance(@recipient.address)
        assert_equal vault_funding - transfer_amount,
                     connection.get_balance(@identity.smart_account_address)
      end

      it 'deducts only the transaction fee from the sponsor' do
        # 2 signatures (payer + creator) at 5000 lamports per signature
        assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
      end

      it 'deducts nothing from the consensus signer' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end
  end

  describe '#compose_execute_transaction_sync' do
    it 'returns a TransactionComposer ready for a fee payer' do
      identity = program.next_smart_account

      composer = program.compose_execute_transaction_sync(
        settings:      identity.settings_address,
        smart_account: identity.smart_account_address,
        signers:       [creator.address],
        instructions:  [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     identity.smart_account_address,
            to:       Solace::Keypair.generate.address,
            lamports: 1
          )
        ]
      )

      assert_kind_of Solace::TransactionComposer, composer
    end
  end

  describe '#get_settings' do
    it 'raises when no settings account exists at the address' do
      missing = Solace::Keypair.generate.address

      error = assert_raises(RuntimeError) { program.get_settings(settings_address: missing) }
      assert_match(/not found/, error.message)
    end
  end
end
