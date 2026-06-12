# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — close a SpendingLimit account with the settings
# authority's single signature, then assert the closure and rent refund.
describe Solace::Composers::SquadsSmartAccountsRemoveSpendingLimitAsAuthorityComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:period) { Solace::SquadsSmartAccounts::Period }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'removing a spending limit from a controlled smart account' do
    before(:all) do
      # Create a controlled account and grant a spending limit.
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address

      @spending_limit_address = grant_spending_limit(
        program,
        identity:,
        authority: creator,
        delegate:  Solace::Keypair.generate.address,
        amount:    100_000_000,
        period:    period::DAY
      )

      # A fresh rent collector proves the refund went to the named account.
      @rent_collector = Solace::Keypair.generate
      @spending_limit_rent = connection.get_balance(@spending_limit_address)

      composer = Solace::Composers::SquadsSmartAccountsRemoveSpendingLimitAsAuthorityComposer.new(
        settings:           @settings_address,
        settings_authority: creator.address,
        spending_limit:     @spending_limit_address,
        rent_collector:     @rent_collector.address
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }
    end

    it 'closes the spending limit account' do
      assert_nil connection.get_account_info(@spending_limit_address)
    end

    it 'refunds the rent to the rent collector' do
      assert_equal @spending_limit_rent, connection.get_balance(@rent_collector.address)
    end
  end
end
