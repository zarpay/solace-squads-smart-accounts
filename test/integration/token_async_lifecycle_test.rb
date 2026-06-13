# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: moving SPL tokens (not SOL) through propose → execute.
#
# The async vault lifecycle is CPI-agnostic: a stored transaction can carry any
# instruction whose authority is the vault PDA, and on execution the program
# signs it as that PDA. Every other lifecycle test moves native SOL via a system
# transfer; this one proves the exact same machinery moves SPL tokens.
#
# The inner instruction is an SPL Token `transfer_checked` whose `authority` is
# the vault PDA — so the vault is the message's signer, exempt from signing the
# outer transaction and instead signed by the program via CPI at execute time,
# precisely as in the SOL case. The vault holds tokens in its associated token
# account (ATA); the destination owner must already have an ATA for the mint
# (transfer_checked credits an existing token account).
#
# THE STORY (1-of-1; `creator` holds ALL, threshold 1; mint = `spl-mint`, 6 decimals)
#   • Fund the vault's ATA by minting tokens to it.
#   • createTransaction(inner: transfer_checked vault_ata → destination_ata,
#     authority = vault) → createProposal → approveProposal → executeTransaction.
#   Result: the destination ATA gains `transfer_amount`; the vault ATA loses it.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: an SPL token transfer through the async lifecycle' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }
  let(:mint) { fixtures.load_keypair('spl-mint') }
  let(:mint_authority) { fixtures.load_keypair('mint-authority') }
  let(:spl_token) { Solace::Programs::SplToken.new(connection:) }
  let(:token_program_id) { Solace::Constants::TOKEN_PROGRAM_ID }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:minted_amount) { 1_000_000 } # base units (6 decimals)
  let(:transfer_amount) { 400_000 }
  let(:decimals) { 6 }

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

    # The vault holds tokens in its ATA. Create it and mint the vault some tokens.
    @vault_ata = create_ata(
      connection,
      payer:            creator,
      owner:            @vault_address,
      mint:             mint.address,
      token_program_id:
    )
    mint_tokens(
      spl_token,
      payer:       creator,
      mint:        mint.address,
      destination: @vault_ata,
      amount:      minted_amount,
      authority:   mint_authority
    )

    # transfer_checked credits an existing token account, so the destination
    # owner needs an ATA up front.
    @recipient       = Solace::Keypair.generate
    @destination_ata = create_ata(
      connection,
      payer:            creator,
      owner:            @recipient.address,
      mint:             mint.address,
      token_program_id:
    )

    # Store a token transfer whose authority is the vault PDA — the program will
    # sign it as the vault during execution, exactly like a SOL transfer.
    create_tx = program.create_transaction(
      payer:        creator,
      settings:     @settings_address,
      creator:,
      rent_payer:   creator,
      instructions: [
        Solace::Composers::SplTokenProgramTransferCheckedComposer.new(
          from:      @vault_ata,
          to:        @destination_ata,
          authority: @vault_address,
          mint:      mint.address,
          amount:    transfer_amount,
          decimals:
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

    @vault_token_before       = connection.get_token_account_balance(@vault_ata)['amount'].to_i
    @destination_token_before = connection.get_token_account_balance(@destination_ata)['amount'].to_i

    execute_tx = program.execute_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { execute_tx.signature }

    @vault_token_after       = connection.get_token_account_balance(@vault_ata)['amount'].to_i
    @destination_token_after = connection.get_token_account_balance(@destination_ata)['amount'].to_i

    @proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )
    @final_status      = program.get_proposal(proposal_address: @proposal_address).status
  end

  it 'starts with the freshly minted balance in the vault ATA' do
    assert_equal minted_amount, @vault_token_before
  end

  it 'credits the destination token account by the transfer amount' do
    assert_equal @destination_token_before + transfer_amount, @destination_token_after
  end

  it 'debits the vault token account by the transfer amount' do
    assert_equal @vault_token_before - transfer_amount, @vault_token_after
  end

  it 'marks the proposal executed' do
    assert_equal :executed, @final_status
  end
end
