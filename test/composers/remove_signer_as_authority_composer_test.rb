# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — remove a signer from a controlled smart account with the
# settings authority's single signature, then assert the on-chain effects.
describe Solace::Composers::SquadsSmartAccountsRemoveSignerAsAuthorityComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'removing a signer from a controlled smart account' do
    before(:all) do
      # Create a controlled smart account with two signers; creator is the authority.
      @removed_signer_key = Solace::Keypair.generate

      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [
          signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
          signer_klass.new(pubkey: @removed_signer_key.address, permission: permissions::VOTE)
        ]
      )

      @settings_address = identity.settings_address

      composer = Solace::Composers::SquadsSmartAccountsRemoveSignerAsAuthorityComposer.new(
        settings:           @settings_address,
        settings_authority: creator.address,
        rent_payer:         creator.address,
        old_signer:         @removed_signer_key.address
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    it 'shrinks the signer set to one' do
      assert_equal 1, @settings.signers.length
    end

    it 'no longer contains the removed signer' do
      refute(@settings.signers.any? { |signer| signer.pubkey == @removed_signer_key.address })
    end

    it 'retains the remaining signer' do
      assert_equal creator.address, @settings.signers.first.pubkey
    end
  end
end
