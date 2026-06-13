# frozen_string_literal: true

require_relative '../test_helper'

# Integration test — cast an approval vote on an active proposal and assert the
# on-chain Proposal transitions to Approved (1-of-1 reaches threshold at once).
describe Solace::Composers::SquadsSmartAccountsApproveProposalComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'approving an active proposal' do
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

      @proposal_address, = program.get_proposal_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      composer = Solace::Composers::SquadsSmartAccountsApproveProposalComposer.new(
        settings: @settings_address,
        signer:   creator.address,
        proposal: @proposal_address
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @proposal = program.get_proposal(proposal_address: @proposal_address)
    end

    it 'marks the proposal approved once approvals reach the threshold' do
      assert_equal :approved, @proposal.status
    end

    it 'records the signer as an approver' do
      assert_includes @proposal.approved, creator.address
    end

    it 'records no rejections' do
      assert_empty @proposal.rejected
    end
  end
end
