# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: one proposal, many instructions, executed atomically.
#
# A stored vault transaction is not limited to a single instruction — it holds a
# whole compiled message. `createTransaction` takes a list of inner composers,
# merges their accounts into one canonical message (deduplicated, ordered), and
# `executeTransaction` replays every instruction in order under a single
# approval, signing each as the vault PDA. Either all of them land or none do.
#
# Every other lifecycle test stores a single transfer; this one proves the
# multi-instruction path: a payroll-style batch that pays TWO recipients out of
# the vault in one approved transaction. It exercises the message machinery more
# than a single transfer does — the compiled message now carries two writable
# recipient accounts plus the shared vault and system program, and the
# execute-time account-metas reconstruction must line them all up correctly.
#
# THE STORY (1-of-1; `creator` holds ALL, threshold 1)
#   createTransaction(instructions: [vault → A (amount_a), vault → B (amount_b)])
#   → createProposal → approveProposal → executeTransaction
#   Result: A gains amount_a, B gains amount_b, the vault loses amount_a+amount_b,
#   all from one proposal.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: a multi-instruction transaction executes atomically' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:vault_funding) { 1_000_000_000 }
  let(:amount_a) { 150_000_000 }
  let(:amount_b) { 350_000_000 }

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
    fund_account(connection, @vault_address, vault_funding)

    @recipient_a = Solace::Keypair.generate
    @recipient_b = Solace::Keypair.generate

    # One transaction, two transfers. Both inner instructions spend from the same
    # vault; createTransaction compiles them into a single message.
    create_tx = program.create_transaction(
      payer:        creator,
      settings:     @settings_address,
      creator:,
      rent_payer:   creator,
      instructions: [
        Solace::Composers::SystemProgramTransferComposer.new(
          from:     @vault_address,
          to:       @recipient_a.address,
          lamports: amount_a
        ),
        Solace::Composers::SystemProgramTransferComposer.new(
          from:     @vault_address,
          to:       @recipient_b.address,
          lamports: amount_b
        )
      ]
    )
    connection.wait_for_confirmed_signature { create_tx.signature }

    @transaction_address, = program.get_transaction_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )
    @stored_transaction   = program.get_transaction(transaction_address: @transaction_address)

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

    @vault_before       = connection.get_balance(@vault_address)
    @recipient_a_before = connection.get_balance(@recipient_a.address)
    @recipient_b_before = connection.get_balance(@recipient_b.address)

    execute_tx = program.execute_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { execute_tx.signature }

    @vault_after       = connection.get_balance(@vault_address)
    @recipient_a_after = connection.get_balance(@recipient_a.address)
    @recipient_b_after = connection.get_balance(@recipient_b.address)
  end

  it 'compiles both transfers and the system program into the stored message' do
    # vault + recipient_a + recipient_b + system program = 4 distinct keys.
    assert_equal 4, @stored_transaction.account_keys.length
  end

  it 'credits the first recipient' do
    assert_equal @recipient_a_before + amount_a, @recipient_a_after
  end

  it 'credits the second recipient' do
    assert_equal @recipient_b_before + amount_b, @recipient_b_after
  end

  it 'debits the vault by the combined total of both transfers' do
    assert_equal @vault_before - (amount_a + amount_b), @vault_after
  end
end
