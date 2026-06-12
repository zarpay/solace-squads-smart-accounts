# frozen_string_literal: true

require_relative '../test_helper'

include Solace::SquadsSmartAccounts
include Solace::SquadsSmartAccounts::Test

# Integration tests — compose, sign, and send createSmartAccount transactions
# against the local test validator, then assert the on-chain effects by
# deserializing the resulting Settings account.
describe Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer do
  let(:creator) { Fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection: connection) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection: connection) }

  describe 'creating an autonomous smart account' do
    before(:all) do
      @program_config = program.get_program_config
      @settings_seed  = @program_config.smart_account_index + 1

      @settings_address, @settings_bump = Solace::Programs::SquadsSmartAccount.get_settings_address(
        settings_seed: @settings_seed
      )

      composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
        creator:   creator,
        treasury:  @program_config.treasury,
        settings:  @settings_address,
        threshold: 1,
        signers:   [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)],
        time_lock: 0
      )

      @treasury_starting_balance = connection.get_balance(@program_config.treasury)

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings_account = connection.get_account_info(@settings_address)
      @settings = program.get_settings(settings_address: @settings_address)
      @treasury_ending_balance = connection.get_balance(@program_config.treasury)
      @program_config_after = program.get_program_config
    end

    describe 'transaction effects' do
      it 'creates the settings account owned by the Squads program' do
        refute_nil @settings_account, 'Expected settings account to exist on-chain'
        assert_equal PROGRAM_ID, @settings_account['owner']
      end

      it 'transfers the creation fee to the treasury' do
        assert_equal @treasury_starting_balance + @program_config.smart_account_creation_fee,
                     @treasury_ending_balance
      end

      it 'increments the smart account index' do
        assert_equal @settings_seed, @program_config_after.smart_account_index
      end
    end

    describe 'settings account state' do
      it 'stores the seed it was derived from' do
        assert_equal @settings_seed, @settings.seed
      end

      it 'stores the threshold' do
        assert_equal 1, @settings.threshold
      end

      it 'stores the time lock' do
        assert_equal 0, @settings.time_lock
      end

      it 'stores the creator as the only signer with all permissions' do
        assert_equal 1, @settings.signers.length
        assert_equal creator.address, @settings.signers.first.pubkey
        assert_equal Permissions::ALL, @settings.signers.first.permission
      end

      it 'is autonomous (settings authority unset)' do
        # The program stores Pubkey::default() when settings_authority is None.
        assert_equal '11111111111111111111111111111111', @settings.settings_authority
      end

      it 'initializes the transaction indexes to zero' do
        assert_equal 0, @settings.transaction_index
        assert_equal 0, @settings.stale_transaction_index
      end

      it 'stores the canonical bump of the settings PDA' do
        assert_equal @settings_bump, @settings.bump
      end
    end
  end

  describe 'creating a smart account with a sponsored fee payer' do
    let(:payer) { Fixtures.load_keypair('payer') }

    before(:all) do
      @program_config = program.get_program_config
      @settings_seed  = @program_config.smart_account_index + 1

      @settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
        settings_seed: @settings_seed
      )

      composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
        creator:   creator,
        treasury:  @program_config.treasury,
        settings:  @settings_address,
        threshold: 1,
        signers:   [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)],
        time_lock: 0
      )

      @payer_starting_balance   = connection.get_balance(payer.address)
      @creator_starting_balance = connection.get_balance(creator.address)

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(payer)

      tx = transaction_composer.compose_transaction
      tx.sign(payer, creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings_account = connection.get_account_info(@settings_address)
      @payer_ending_balance   = connection.get_balance(payer.address)
      @creator_ending_balance = connection.get_balance(creator.address)
    end

    describe 'transaction effects' do
      it 'creates the settings account owned by the Squads program' do
        refute_nil @settings_account, 'Expected settings account to exist on-chain'
        assert_equal PROGRAM_ID, @settings_account['owner']
      end

      it 'deducts only the transaction fee from the payer' do
        # 2 signatures at 5000 lamports per signature
        assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
      end

      it 'deducts the creation fee and settings rent from the creator' do
        assert_equal @creator_starting_balance - @program_config.smart_account_creation_fee -
                     @settings_account['lamports'],
                     @creator_ending_balance
      end
    end
  end

  describe 'creating a controlled smart account with multiple signers' do
    before(:all) do
      @program_config = program.get_program_config
      @settings_seed  = @program_config.smart_account_index + 1

      @settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
        settings_seed: @settings_seed
      )

      @settings_authority = Solace::Keypair.generate
      @second_signer      = Solace::Keypair.generate

      composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
        creator:            creator,
        treasury:           @program_config.treasury,
        settings:           @settings_address,
        threshold:          2,
        signers:            [
          SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL),
          SmartAccountSigner.new(pubkey: @second_signer.address,
                                 permission: Permissions.mask(:initiate, :vote))
        ],
        time_lock:          3600,
        settings_authority: @settings_authority.address,
        # rent_collector and memo are accepted by the program but not stored in
        # the Settings account — passed here to exercise their encoding end-to-end.
        rent_collector:     Solace::Keypair.generate.address,
        memo:               'created by solace-squads-smart-accounts tests'
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    describe 'settings account state' do
      it 'stores the settings authority (controlled smart account)' do
        assert_equal @settings_authority.address, @settings.settings_authority
      end

      it 'stores the threshold' do
        assert_equal 2, @settings.threshold
      end

      it 'stores the time lock' do
        assert_equal 3600, @settings.time_lock
      end

      it 'stores both signers with their permissions' do
        assert_equal 2, @settings.signers.length

        # The program sorts signers by pubkey, so look them up rather than rely on order.
        creator_signer = @settings.signers.find { |signer| signer.pubkey == creator.address }
        second_signer  = @settings.signers.find { |signer| signer.pubkey == @second_signer.address }

        assert_equal Permissions::ALL, creator_signer.permission
        assert_equal Permissions.mask(:initiate, :vote), second_signer.permission
      end
    end
  end
end
