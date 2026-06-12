# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — hand the settings authority of a controlled smart account
# to a new key, then assert the handoff actually transfers power.
describe Solace::Composers::SquadsSmartAccountsSetNewSettingsAuthorityAsAuthorityComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'handing the settings authority to a new key' do
    before(:all) do
      # Create a controlled 1-of-1 smart account; creator is the authority.
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address
      @new_authority    = Solace::Keypair.generate

      composer = Solace::Composers::SquadsSmartAccountsSetNewSettingsAuthorityAsAuthorityComposer.new(
        settings:               @settings_address,
        settings_authority:     creator.address,
        rent_payer:             creator.address,
        new_settings_authority: @new_authority.address
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
    end

    it 'stores the new settings authority' do
      assert_equal @new_authority.address, @settings.settings_authority
    end

    it 'strips the old authority of its power' do
      error = assert_raises(Solace::Errors::RPCError) do
        program.set_time_lock_as_authority(
          payer:              creator,
          settings:           @settings_address,
          settings_authority: creator,
          rent_payer:         creator,
          time_lock:          60
        )
      end

      # Unauthorized — error code 6005 (0x1775)
      assert_match(/0x1775/, error.message)
    end

    it 'empowers the new authority' do
      tx = program.set_time_lock_as_authority(
        payer:              creator,
        settings:           @settings_address,
        settings_authority: @new_authority,
        rent_payer:         creator,
        time_lock:          60
      )

      connection.wait_for_confirmed_signature { tx.signature }

      assert_equal 60, program.get_settings(settings_address: @settings_address).time_lock
    end
  end
end
