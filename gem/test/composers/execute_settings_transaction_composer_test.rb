# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — the full settings-transaction async lifecycle: store a
# ChangeThreshold action, open and approve its proposal, then execute it and
# assert the settings threshold actually changes.
describe Solace::Composers::SquadsSmartAccountsExecuteSettingsTransactionComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  let(:creator) { fixtures.load_keypair('creator') }
  let(:extra_signer) { Solace::Keypair.generate }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'applying a settings transaction' do
    before(:all) do
      # A 2-of-2 account would block its own proposal, so start 1-of-1 and add a
      # second signer atomically with a threshold bump in one settings transaction.
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
        actions:    [
          action_klass.add_signer(pubkey: extra_signer.address, permission: permissions::ALL),
          action_klass.change_threshold(2)
        ]
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

      @proposal_address,    = program.get_proposal_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )
      @transaction_address, = program.get_transaction_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      composer = Solace::Composers::SquadsSmartAccountsExecuteSettingsTransactionComposer.new(
        settings:    @settings_address,
        signer:      creator.address,
        proposal:    @proposal_address,
        transaction: @transaction_address,
        rent_payer:  creator.address
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @settings = program.get_settings(settings_address: @settings_address)
      @proposal = program.get_proposal(proposal_address: @proposal_address)
    end

    it 'raises the threshold per the applied action' do
      assert_equal 2, @settings.threshold
    end

    it 'adds the new signer per the applied action' do
      assert_includes @settings.signers.map(&:pubkey), extra_signer.address
    end

    it 'marks the proposal executed' do
      assert_equal :executed, @proposal.status
    end
  end
end
