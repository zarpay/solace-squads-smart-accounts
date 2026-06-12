# frozen_string_literal: true

require_relative '../test_helper'

include Solace::SquadsSmartAccounts
include Solace::SquadsSmartAccounts::Test

# Integration tests — add a signer to a controlled smart account with the
# settings authority's single signature, then assert the on-chain effects.
describe Solace::Composers::SquadsSmartAccountsAddSignerAsAuthorityComposer do
  let(:creator) { Fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection: connection) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection: connection) }

  describe 'adding a signer to a controlled smart account' do
    before(:all) do
      # Create a controlled 1-of-1 smart account with creator as the authority.
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:            creator,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)]
      )

      @settings_address = identity.settings_address
      @new_signer_key   = Solace::Keypair.generate

      composer = Solace::Composers::SquadsSmartAccountsAddSignerAsAuthorityComposer.new(
        settings:           @settings_address,
        settings_authority: creator.address,
        rent_payer:         creator.address,
        new_signer:         SmartAccountSigner.new(
          pubkey:     @new_signer_key.address,
          permission: Permissions.mask(:initiate, :vote)
        )
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    it 'grows the signer set to two' do
      assert_equal 2, @settings.signers.length
    end

    it 'stores the new signer with its granted permissions' do
      added = @settings.signers.find { |signer| signer.pubkey == @new_signer_key.address }

      refute_nil added, 'Expected the new signer to be present in the settings'
      assert_equal Permissions.mask(:initiate, :vote), added.permission
    end

    it 'leaves the threshold unchanged' do
      assert_equal 1, @settings.threshold
    end
  end
end
