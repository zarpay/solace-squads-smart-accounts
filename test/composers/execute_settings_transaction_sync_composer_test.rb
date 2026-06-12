# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — atomically apply a batch of SettingsActions to an
# autonomous smart account with threshold co-signers, then assert the
# on-chain effects.
describe Solace::Composers::SquadsSmartAccountsExecuteSettingsTransactionSyncComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'batching settings changes on an autonomous smart account' do
    before(:all) do
      # Create an autonomous 1-of-1 smart account.
      identity = create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address
      @new_signer_key   = Solace::Keypair.generate

      # Atomically add a second signer and raise the threshold to 2.
      composer = Solace::Composers::SquadsSmartAccountsExecuteSettingsTransactionSyncComposer.new(
        settings:   @settings_address,
        signers:    [creator.address],
        rent_payer: creator.address,
        actions:    [
          action_klass.add_signer(pubkey: @new_signer_key.address, permission: permissions::ALL),
          action_klass.change_threshold(2),
          action_klass.set_time_lock(600)
        ]
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    it 'adds the new signer' do
      added = @settings.signers.find { |signer| signer.pubkey == @new_signer_key.address }

      refute_nil added
      assert_equal permissions::ALL, added.permission
    end

    it 'raises the threshold' do
      assert_equal 2, @settings.threshold
    end

    it 'sets the time lock' do
      assert_equal 600, @settings.time_lock
    end
  end
end
