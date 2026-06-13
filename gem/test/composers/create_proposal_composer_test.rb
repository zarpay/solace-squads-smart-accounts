# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — store a transaction, then open a proposal for it and assert
# the on-chain Proposal account. Voting and execution are exercised separately.
describe Solace::Composers::SquadsSmartAccountsCreateProposalComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'opening a proposal for a stored transaction' do
    before(:all) do
      # Autonomous 1-of-1 smart account; fund the default vault and store a transfer.
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

      @proposal_address, = program.get_proposal_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      composer = Solace::Composers::SquadsSmartAccountsCreateProposalComposer.new(
        settings:          @settings_address,
        proposal:          @proposal_address,
        creator:           creator.address,
        rent_payer:        creator.address,
        transaction_index: 1
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @proposal = program.get_proposal(proposal_address: @proposal_address)
    end

    it 'creates the proposal for transaction index 1' do
      assert_equal 1, @proposal.transaction_index
      assert_equal @settings_address, @proposal.settings
    end

    it 'starts the proposal active when not a draft' do
      assert_equal :active, @proposal.status
    end

    it 'records no votes yet' do
      assert_empty @proposal.approved
      assert_empty @proposal.rejected
      assert_empty @proposal.cancelled
    end
  end
end
