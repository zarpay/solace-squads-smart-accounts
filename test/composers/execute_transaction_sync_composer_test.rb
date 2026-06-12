# frozen_string_literal: true

require_relative '../test_helper'

include Solace::SquadsSmartAccounts
include Solace::SquadsSmartAccounts::Test

# Integration tests — execute a transfer out of a smart account vault in a
# single transaction by reaching threshold with co-signers (1-of-1).
describe Solace::Composers::SquadsSmartAccountsExecuteTransactionSyncComposer do
  let(:creator) { Fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection: connection) }

  describe 'transferring SOL out of the default vault' do
    # Amount funded into the vault and amount transferred out of it.
    let(:vault_funding)   { 1_000_000_000 }
    let(:transfer_amount) { 250_000_000 }

    before(:all) do
      # 1. Create a fresh 1-of-1 smart account.
      program_config = ProgramConfig.load(connection)

      @settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
        settings_seed: program_config.smart_account_index + 1
      )

      create_composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
        creator:   creator,
        treasury:  program_config.treasury,
        settings:  @settings_address,
        threshold: 1,
        signers:   [SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL)],
        time_lock: 0
      )

      create_tx_composer = Solace::TransactionComposer.new(connection: connection)
      create_tx_composer.add_instruction(create_composer)
      create_tx_composer.set_fee_payer(creator)

      tx = create_tx_composer.compose_transaction
      tx.sign(creator)

      signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { signature['result'] }

      # 2. Fund the default vault (account index 0).
      @vault_address, = Solace::Programs::SquadsSmartAccount.get_smart_account_address(
        settings_address: @settings_address
      )

      signature = connection.request_airdrop(@vault_address, vault_funding)
      connection.wait_for_confirmed_signature { signature['result'] }

      # 3. Execute a transfer out of the vault, co-signed by the sole signer.
      @recipient = Solace::Keypair.generate

      sync_composer = Solace::Composers::SquadsSmartAccountsExecuteTransactionSyncComposer.new(
        settings:      @settings_address,
        smart_account: @vault_address,
        signers:       [creator.address],
        instructions:  [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     @vault_address,
            to:       @recipient.address,
            lamports: transfer_amount
          )
        ]
      )

      transaction_composer.add_instruction(sync_composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @recipient_ending_balance = connection.get_balance(@recipient.address)
      @vault_ending_balance     = connection.get_balance(@vault_address)
    end

    it 'transfers the amount to the recipient' do
      assert_equal transfer_amount, @recipient_ending_balance
    end

    it 'deducts the amount from the vault' do
      assert_equal vault_funding - transfer_amount, @vault_ending_balance
    end

    it 'leaves the settings account untouched' do
      settings = Settings.load(connection, @settings_address)

      assert_equal 1, settings.threshold
      assert_equal 0, settings.transaction_index
    end
  end

  describe 'transferring SOL out of a vault with threshold 2' do
    let(:payer) { Fixtures.load_keypair('payer') }

    let(:vault_funding)   { 1_000_000_000 }
    let(:transfer_amount) { 250_000_000 }

    before(:all) do
      # 1. Create a 2-of-2 smart account with creator and payer as signers.
      program_config = ProgramConfig.load(connection)

      @settings_address, = Solace::Programs::SquadsSmartAccount.get_settings_address(
        settings_seed: program_config.smart_account_index + 1
      )

      create_composer = Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer.new(
        creator:   creator,
        treasury:  program_config.treasury,
        settings:  @settings_address,
        threshold: 2,
        signers:   [
          SmartAccountSigner.new(pubkey: creator.address, permission: Permissions::ALL),
          SmartAccountSigner.new(pubkey: payer.address, permission: Permissions::ALL)
        ],
        time_lock: 0
      )

      create_tx_composer = Solace::TransactionComposer.new(connection: connection)
      create_tx_composer.add_instruction(create_composer)
      create_tx_composer.set_fee_payer(creator)

      tx = create_tx_composer.compose_transaction
      tx.sign(creator)

      signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { signature['result'] }

      # 2. Fund the default vault.
      @vault_address, = Solace::Programs::SquadsSmartAccount.get_smart_account_address(
        settings_address: @settings_address
      )

      signature = connection.request_airdrop(@vault_address, vault_funding)
      connection.wait_for_confirmed_signature { signature['result'] }

      # 3. Execute a transfer out of the vault, co-signed by both signers.
      @recipient = Solace::Keypair.generate

      sync_composer = Solace::Composers::SquadsSmartAccountsExecuteTransactionSyncComposer.new(
        settings:      @settings_address,
        smart_account: @vault_address,
        signers:       [creator.address, payer.address],
        instructions:  [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     @vault_address,
            to:       @recipient.address,
            lamports: transfer_amount
          )
        ]
      )

      transaction_composer.add_instruction(sync_composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator, payer)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @recipient_ending_balance = connection.get_balance(@recipient.address)
      @vault_ending_balance     = connection.get_balance(@vault_address)
    end

    it 'transfers the amount to the recipient' do
      assert_equal transfer_amount, @recipient_ending_balance
    end

    it 'deducts the amount from the vault' do
      assert_equal vault_funding - transfer_amount, @vault_ending_balance
    end

    it 'stores both signers and the threshold in the settings account' do
      settings = Settings.load(connection, @settings_address)

      assert_equal 2, settings.threshold
      assert_equal 2, settings.signers.length
    end
  end
end
