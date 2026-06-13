# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — after a vault transaction's proposal is rejected (a terminal
# state), close the transaction and its proposal and assert both accounts are
# gone and the rent is refunded.
describe Solace::Composers::SquadsSmartAccountsCloseTransactionComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'closing a rejected vault transaction' do
    before(:all) do
      identity = create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address
      @vault_address    = identity.smart_account_address
      fund_account(connection, @vault_address, 1_000_000_000)

      @recipient = Solace::Keypair.generate

      create_tx = program.create_transaction(
        payer:        creator,
        settings:     @settings_address,
        creator:,
        rent_payer:   creator,
        instructions: [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     @vault_address,
            to:       @recipient.address,
            lamports: 250_000_000
          )
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

      # Reject so the proposal reaches a terminal state and the transaction can close.
      reject_tx = program.reject_proposal(
        payer:             creator,
        settings:          @settings_address,
        signer:            creator,
        transaction_index: 1
      )
      connection.wait_for_confirmed_signature { reject_tx.signature }

      @proposal_address,    = program.get_proposal_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )
      @transaction_address, = program.get_transaction_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      composer = Solace::Composers::SquadsSmartAccountsCloseTransactionComposer.new(
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
    end

    it 'closes the vault transaction account' do
      assert_nil connection.get_account_info(@transaction_address)
    end

    it 'closes the proposal account' do
      assert_nil connection.get_account_info(@proposal_address)
    end
  end
end
