# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — create a SOL spending limit on a controlled smart account
# with the settings authority's single signature, then assert the on-chain
# SpendingLimit account state.
describe Solace::Composers::SquadsSmartAccountsAddSpendingLimitAsAuthorityComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:period) { Solace::SquadsSmartAccounts::Period }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'creating a SOL spending limit on a controlled smart account' do
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
      @seed             = Solace::Keypair.generate
      @allowed_signer   = Solace::Keypair.generate

      @spending_limit_address, = program.get_spending_limit_address(
        settings_address: @settings_address,
        seed:             @seed
      )

      composer = Solace::Composers::SquadsSmartAccountsAddSpendingLimitAsAuthorityComposer.new(
        settings:           @settings_address,
        settings_authority: creator.address,
        spending_limit:     @spending_limit_address,
        rent_payer:         creator.address,
        seed:               @seed,
        amount:             500_000_000,
        period:             period::DAY,
        signers:            [@allowed_signer.address]
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)
    end

    it 'links the limit to its settings account and seed' do
      assert_equal @settings_address, @spending_limit.settings
      assert_equal @seed.address, @spending_limit.seed
    end

    it 'marks the limit as SOL via the default pubkey mint' do
      assert_equal Solace::SquadsSmartAccounts::DEFAULT_PUBKEY, @spending_limit.mint
    end

    it 'stores the amount with a full remaining balance' do
      assert_equal 500_000_000, @spending_limit.amount
      assert_equal 500_000_000, @spending_limit.remaining_amount
    end

    it 'stores the period' do
      assert_equal period::DAY, @spending_limit.period
    end

    it 'stores the allowed signer' do
      assert_equal [@allowed_signer.address], @spending_limit.signers
    end

    it 'allows any destination by default' do
      assert_empty @spending_limit.destinations
    end

    it 'never expires by default' do
      assert_equal Solace::SquadsSmartAccounts::I64_MAX, @spending_limit.expiration
    end

    it 'targets the default vault by default' do
      assert_equal 0, @spending_limit.account_index
    end
  end
end
