# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — change the threshold of a controlled smart account with
# the settings authority's single signature, then assert the on-chain effects.
describe Solace::Composers::SquadsSmartAccountsChangeThresholdAsAuthorityComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'changing the threshold of a controlled smart account' do
    before(:all) do
      # Create a controlled 1-of-2 smart account; creator is the authority.
      second_signer = Solace::Keypair.generate

      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [
          signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
          signer_klass.new(pubkey: second_signer.address, permission: permissions::ALL)
        ]
      )

      @settings_address = identity.settings_address

      composer = Solace::Composers::SquadsSmartAccountsChangeThresholdAsAuthorityComposer.new(
        settings:           @settings_address,
        settings_authority: creator.address,
        rent_payer:         creator.address,
        new_threshold:      2
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    it 'updates the threshold' do
      assert_equal 2, @settings.threshold
    end

    it 'leaves the signer set unchanged' do
      assert_equal 2, @settings.signers.length
    end
  end
end
