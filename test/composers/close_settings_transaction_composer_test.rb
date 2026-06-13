# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — after a settings transaction executes, close it and its
# proposal and assert both accounts are gone and the rent is refunded.
describe Solace::Composers::SquadsSmartAccountsCloseSettingsTransactionComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'closing an executed settings transaction' do
    before(:all) do
      identity = create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address

      create_tx = program.create_settings_transaction(
        payer:      creator,
        settings:   @settings_address,
        creator:,
        rent_payer: creator,
        actions:    [action_klass.change_threshold(1)]
      )
      connection.wait_for_confirmed_signature { create_tx.signature }

      propose_tx = program.create_proposal(
        payer:             creator,
        settings:          @settings_address,
        creator:,
        rent_payer:        creator,
        transaction_index: 1
      )
      connection.wait_for_confirmed_signature { propose_tx.signature }

      approve_tx = program.approve_proposal(
        payer:             creator,
        settings:          @settings_address,
        signer:            creator,
        transaction_index: 1
      )
      connection.wait_for_confirmed_signature { approve_tx.signature }

      execute_tx = program.execute_settings_transaction(
        payer:             creator,
        settings:          @settings_address,
        signer:            creator,
        transaction_index: 1,
        rent_payer:        creator
      )
      connection.wait_for_confirmed_signature { execute_tx.signature }

      @proposal_address,    = program.get_proposal_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )
      @transaction_address, = program.get_transaction_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      @creator_before = connection.get_balance(creator.address)

      composer = Solace::Composers::SquadsSmartAccountsCloseSettingsTransactionComposer.new(
        settings:                   @settings_address,
        proposal:                   @proposal_address,
        transaction:                @transaction_address,
        proposal_rent_collector:    creator.address,
        transaction_rent_collector: creator.address
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @creator_after = connection.get_balance(creator.address)
    end

    it 'closes the settings transaction account' do
      assert_nil connection.get_account_info(@transaction_address)
    end

    it 'closes the proposal account' do
      assert_nil connection.get_account_info(@proposal_address)
    end

    it 'refunds the rent to the collector net of the transaction fee' do
      # Rent of both closed accounts returns to the creator, who also pays the
      # 5000-lamport single-signature fee — so the net change is strictly positive.
      assert_operator @creator_after, :>, @creator_before
    end
  end
end
