# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — the full async lifecycle through execution: store a vault
# transfer, open and approve its proposal, then execute it and assert the funds
# actually move and the proposal is marked Executed.
describe Solace::Composers::SquadsSmartAccountsExecuteTransactionComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'executing an approved transaction' do
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

      @vault_before      = connection.get_balance(@vault_address)
      @recipient_before  = connection.get_balance(@recipient.address)

      transaction = program.get_transaction(transaction_address: @transaction_address)

      composer = Solace::Composers::SquadsSmartAccountsExecuteTransactionComposer.new(
        settings:      @settings_address,
        proposal:      @proposal_address,
        transaction:   @transaction_address,
        signer:        creator.address,
        smart_account: @vault_address,
        account_metas: transaction.account_metas
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @vault_after     = connection.get_balance(@vault_address)
      @recipient_after = connection.get_balance(@recipient.address)
      @proposal        = program.get_proposal(proposal_address: @proposal_address)
    end

    it 'credits the recipient by the transfer amount' do
      assert_equal 0, @recipient_before
      assert_equal 250_000_000, @recipient_after
    end

    it 'debits the vault by the transfer amount' do
      assert_equal 1_000_000_000, @vault_before
      assert_equal 1_000_000_000 - 250_000_000, @vault_after
    end

    it 'marks the proposal executed' do
      assert_equal :executed, @proposal.status
    end
  end
end
