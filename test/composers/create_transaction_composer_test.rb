# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — store a pending vault transaction on-chain, then assert
# the Transaction account and its compiled inner message. Funds do not move
# here; execution is the proposal flow (Phase 2).
describe Solace::Composers::SquadsSmartAccountsCreateTransactionComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'storing a vault transfer transaction' do
    before(:all) do
      # Autonomous 1-of-1 smart account; fund the default vault.
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

      @transaction_address, = program.get_transaction_address(
        settings_address:  @settings_address,
        transaction_index: 1
      )

      composer = Solace::Composers::SquadsSmartAccountsCreateTransactionComposer.new(
        settings:     @settings_address,
        transaction:  @transaction_address,
        creator:      creator.address,
        rent_payer:   creator.address,
        instructions: [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     @vault_address,
            to:       @recipient.address,
            lamports: 250_000_000
          )
        ]
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @transaction = program.get_transaction(transaction_address: @transaction_address)
    end

    it 'creates the transaction at index 1 for the default vault' do
      assert_equal 1, @transaction.index
      assert_equal 0, @transaction.account_index
      assert_equal @settings_address, @transaction.settings
    end

    it 'compiles the inner message header for a single-signer transfer' do
      assert_equal 1, @transaction.num_signers
      assert_equal 1, @transaction.num_writable_signers
      assert_equal 1, @transaction.num_writable_non_signers
    end

    it 'stores the vault, recipient, and system program as the account keys' do
      assert_equal 3, @transaction.account_keys.length
      assert_includes @transaction.account_keys, @vault_address
      assert_includes @transaction.account_keys, @recipient.address
      assert_includes @transaction.account_keys, Solace::Constants::SYSTEM_PROGRAM_ID
    end

    it 'orders the vault first as the sole writable signer' do
      assert_equal @vault_address, @transaction.account_keys.first
    end

    it 'leaves the vault funds untouched (execution is deferred)' do
      assert_equal 1_000_000_000, connection.get_balance(@vault_address)
    end
  end
end
