# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests — spend SOL from a vault within a pre-authorized spending
# limit, then assert balances, the decremented allowance, and the program's
# enforcement of the limit's boundaries.
describe Solace::Composers::SquadsSmartAccountsUseSpendingLimitComposer do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:period) { Solace::SquadsSmartAccounts::Period }

  let(:creator) { fixtures.load_keypair('creator') }
  let(:payer) { fixtures.load_keypair('payer') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }
  let(:transaction_composer) { Solace::TransactionComposer.new(connection:) }

  describe 'spending SOL within the limit' do
    let(:vault_funding) { 1_000_000_000 }
    let(:limit_amount)  { 500_000_000 }
    let(:spend_amount)  { 200_000_000 }

    before(:all) do
      # 1. Controlled smart account; creator is authority AND the allowed signer.
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      @settings_address = identity.settings_address
      @vault_address    = identity.smart_account_address
      @seed             = Solace::Keypair.generate

      # 2. Grant the spending limit.
      @spending_limit_address, = program.get_spending_limit_address(
        settings_address: @settings_address,
        seed:             @seed
      )

      tx = program.add_spending_limit_as_authority(
        payer:              creator,
        settings:           @settings_address,
        settings_authority: creator,
        rent_payer:         creator,
        spending_limit:     @spending_limit_address,
        seed:               @seed,
        amount:             limit_amount,
        period:             period::DAY,
        signers:            [creator.address]
      )
      connection.wait_for_confirmed_signature { tx.signature }

      # 3. Fund the vault.
      signature = connection.request_airdrop(@vault_address, vault_funding)
      connection.wait_for_confirmed_signature { signature['result'] }

      # 4. Spend within the limit via the composer.
      @recipient = Solace::Keypair.generate

      composer = Solace::Composers::SquadsSmartAccountsUseSpendingLimitComposer.new(
        settings:       @settings_address,
        signer:         creator.address,
        spending_limit: @spending_limit_address,
        smart_account:  @vault_address,
        destination:    @recipient.address,
        amount:         spend_amount
      )

      transaction_composer.add_instruction(composer)
      transaction_composer.set_fee_payer(creator)

      tx = transaction_composer.compose_transaction
      tx.sign(creator)

      @signature = connection.send_transaction(tx.serialize)
      connection.wait_for_confirmed_signature { @signature['result'] }

      @spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)
    end

    it 'transfers the amount to the destination' do
      assert_equal spend_amount, connection.get_balance(@recipient.address)
    end

    it 'deducts the amount from the vault' do
      assert_equal vault_funding - spend_amount, connection.get_balance(@vault_address)
    end

    it 'decrements the remaining allowance' do
      assert_equal limit_amount - spend_amount, @spending_limit.remaining_amount
      assert_equal limit_amount, @spending_limit.amount
    end

    it 'rejects a spend exceeding the remaining allowance' do
      error = assert_raises(Solace::Errors::RPCError) do
        program.use_spending_limit(
          payer:          creator,
          settings:       @settings_address,
          signer:         creator,
          spending_limit: @spending_limit_address,
          smart_account:  @vault_address,
          destination:    @recipient.address,
          amount:         limit_amount # > remaining after the spend above
        )
      end

      # SpendingLimitExceeded — error code 6027 (0x178b)
      assert_match(/0x178b/, error.message)
    end

    it 'rejects a signer the limit does not allow' do
      error = assert_raises(Solace::Errors::RPCError) do
        program.use_spending_limit(
          payer:,
          settings:       @settings_address,
          signer:         payer, # funded, but not in the limit's signers
          spending_limit: @spending_limit_address,
          smart_account:  @vault_address,
          destination:    @recipient.address,
          amount:         1_000
        )
      end

      assert_kind_of Solace::Errors::RPCError, error
    end
  end

  # Performs a token spending-limit spend through the composer and assigns the
  # captured state to instance variables (limit_amount, transfer_amount,
  # minted_amount, and the starting/ending balances) for the scenarios below.
  #
  # @param token_program [Solace::Programs::SplToken, Solace::Programs::Token2022] The token client.
  # @param mint_fixture [String] The mint fixture name.
  # @param token_program_id [String] The program owning the mint.
  # @return [void]
  def perform_token_spend(token_program:, mint_fixture:, token_program_id:)
    mint           = fixtures.load_keypair(mint_fixture)
    mint_authority = fixtures.load_keypair('mint-authority')

    @minted_amount   = 1_000_000
    @limit_amount    = 500_000
    @transfer_amount = 200_000

    identity = create_smart_account(
      program,
      payer:              creator,
      creator:,
      threshold:          1,
      settings_authority: creator.address,
      signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
    )

    # Grant a token-denominated spending limit (mint != default).
    spending_limit_address = grant_spending_limit(
      program,
      identity:,
      authority: creator,
      delegate:  creator.address,
      amount:    @limit_amount,
      period:    period::DAY,
      mint:      mint.address
    )

    # Fund the vault's ATA with tokens; create the destination owner's ATA.
    vault_ata = create_ata(
      connection,
      payer:            creator,
      owner:            identity.smart_account_address,
      mint:             mint.address,
      token_program_id:
    )

    mint_tokens(
      token_program,
      payer:       creator,
      mint:        mint.address,
      destination: vault_ata,
      amount:      @minted_amount,
      authority:   mint_authority
    )

    recipient = Solace::Keypair.generate
    destination_ata = create_ata(
      connection,
      payer:            creator,
      owner:            recipient.address,
      mint:             mint.address,
      token_program_id:
    )

    @recipient_starting_balance = connection.get_token_account_balance(destination_ata)['amount'].to_i
    @vault_starting_balance     = connection.get_token_account_balance(vault_ata)['amount'].to_i
    @starting_remaining_amount  = program.get_spending_limit(spending_limit_address:).remaining_amount

    composer = Solace::Composers::SquadsSmartAccountsUseSpendingLimitComposer.new(
      settings:                    identity.settings_address,
      signer:                      creator.address,
      spending_limit:              spending_limit_address,
      smart_account:               identity.smart_account_address,
      destination:                 recipient.address,
      amount:                      @transfer_amount,
      decimals:                    6,
      mint:                        mint.address,
      token_program:               token_program_id,
      smart_account_token_account: vault_ata,
      destination_token_account:   destination_ata
    )

    tx = Solace::TransactionComposer.new(connection:)
                                    .add_instruction(composer)
                                    .set_fee_payer(creator)
                                    .compose_transaction

    tx.sign(creator)

    signature = connection.send_transaction(tx.serialize)
    connection.wait_for_confirmed_signature { signature['result'] }

    @recipient_ending_balance = connection.get_token_account_balance(destination_ata)['amount'].to_i
    @vault_ending_balance     = connection.get_token_account_balance(vault_ata)['amount'].to_i
    @ending_remaining_amount  = program.get_spending_limit(spending_limit_address:).remaining_amount
  end

  describe 'spending an SPL Token limit' do
    before(:all) do
      perform_token_spend(
        token_program:    Solace::Programs::SplToken.new(connection:),
        mint_fixture:     'spl-mint',
        token_program_id: Solace::Constants::TOKEN_PROGRAM_ID
      )
    end

    it 'credits the transfer amount to the destination' do
      assert_equal @recipient_starting_balance + @transfer_amount, @recipient_ending_balance
    end

    it 'debits the transfer amount from the vault' do
      assert_equal @vault_starting_balance - @transfer_amount, @vault_ending_balance
    end

    it 'decrements the remaining allowance by the transfer amount' do
      assert_equal @starting_remaining_amount - @transfer_amount, @ending_remaining_amount
    end
  end

  describe 'spending a Token-2022 limit' do
    before(:all) do
      perform_token_spend(
        token_program:    Solace::Programs::Token2022.new(connection:),
        mint_fixture:     'token-2022-mint',
        token_program_id: Solace::Constants::TOKEN_2022_PROGRAM_ID
      )
    end

    it 'credits the transfer amount to the destination' do
      assert_equal @recipient_starting_balance + @transfer_amount, @recipient_ending_balance
    end

    it 'debits the transfer amount from the vault' do
      assert_equal @vault_starting_balance - @transfer_amount, @vault_ending_balance
    end

    it 'decrements the remaining allowance by the transfer amount' do
      assert_equal @starting_remaining_amount - @transfer_amount, @ending_remaining_amount
    end
  end
end
