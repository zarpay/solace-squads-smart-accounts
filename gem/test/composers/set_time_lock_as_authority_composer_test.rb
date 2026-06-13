# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — set the time lock of a controlled smart account with the
# settings authority's single signature, then assert the on-chain effects.
describe Solace::Composers::SquadsSmartAccountsSetTimeLockAsAuthorityComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'setting the time lock of a controlled smart account' do
    before(:all) do
      # Create a controlled 1-of-1 smart account with no time lock.
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address

      composer = Solace::Composers::SquadsSmartAccountsSetTimeLockAsAuthorityComposer.new(
        settings:           @settings_address,
        settings_authority: creator.address,
        rent_payer:         creator.address,
        time_lock:          3600
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    it 'updates the time lock' do
      assert_equal 3600, @settings.time_lock
    end

    it 'leaves the threshold and signer set unchanged' do
      assert_equal 1, @settings.threshold
      assert_equal 1, @settings.signers.length
    end
  end
end
