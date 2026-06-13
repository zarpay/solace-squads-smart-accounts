# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — store a settings transaction (a batch of SettingsActions)
# on-chain and assert the SettingsTransaction account. Application happens later
# via the proposal flow.
describe Solace::Composers::SquadsSmartAccountsCreateSettingsTransactionComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'storing a settings transaction' do
    before(:all) do
      # Autonomous 1-of-1 smart account (createSettingsTransaction rejects controlled).
      identity = create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address

      @transaction_address, = program.get_transaction_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      composer = Solace::Composers::SquadsSmartAccountsCreateSettingsTransactionComposer.new(
        settings:    @settings_address,
        transaction: @transaction_address,
        creator:     creator.address,
        rent_payer:  creator.address,
        actions:     [action_klass.change_threshold(2)]
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @transaction = program.get_settings_transaction(transaction_address: @transaction_address)
    end

    it 'stores the transaction at index 1' do
      assert_equal 1, @transaction.index
    end

    it 'records the settings account' do
      assert_equal @settings_address, @transaction.settings
    end

    it 'records the creator' do
      assert_equal creator.address, @transaction.creator
    end

    it 'records the rent collector' do
      assert_equal creator.address, @transaction.rent_collector
    end
  end
end
