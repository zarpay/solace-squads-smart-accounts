# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: the time lock delays execution after approval.
#
# A smart account can carry a `time_lock` (seconds). It is a cooling-off period:
# once a proposal is Approved, the transaction cannot execute until at least
# `time_lock` seconds have elapsed since the approval timestamp. The execute
# handler enforces this with:
#     now - approved_timestamp >= time_lock      (else TimeLockNotReleased)
# This gives signers a window to notice and cancel a payment they disagree with
# before it can settle.
#
# Every other test in this suite uses time_lock 0 (instant execution), so this is
# the only place the gate actually fires. We use a short lock and a real wait:
#   • Create a 1-of-1 account with time_lock = TIME_LOCK seconds, fund the vault.
#   • Propose and approve a transfer (this stamps the approval time).
#   • Execute IMMEDIATELY → rejected with TimeLockNotReleased.
#   • Sleep past the lock, then execute → the transfer settles.
#
# The validator's on-chain clock tracks wall-clock time, so a real `sleep` longer
# than the lock is what releases it.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: the time lock delays execution' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:vault_funding)   { 1_000_000_000 }
  let(:transfer_amount) { 250_000_000 }

  # Seconds. Kept small so the test stays fast; the sleep below clears it with margin.
  let(:time_lock_seconds) { 3 }

  # Runs the block and reports whether the program rejected it at submission.
  def rpc_rejected?
    yield
    false
  rescue Solace::Errors::RPCError
    true
  end

  before(:all) do
    # A 1-of-1 account carrying a non-zero time lock.
    identity = create_smart_account(
      program,
      payer:     creator,
      creator:,
      threshold: 1,
      time_lock: time_lock_seconds,
      signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
    )

    @settings_address = identity.settings_address
    @vault_address    = identity.smart_account_address
    fund_account(connection, @vault_address, vault_funding)

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
          lamports: transfer_amount
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

    # Approving stamps the timestamp the time lock is measured from.
    approve_tx = program.approve_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { approve_tx.signature }

    # Attempt to execute before the lock elapses — the program refuses
    # (TimeLockNotReleased). Funds must not move.
    @early_execute_rejected = rpc_rejected? do
      program.execute_transaction(
        payer:             creator,
        settings:          @settings_address,
        signer:            creator,
        transaction_index: 1
      )
    end
    @recipient_after_early  = connection.get_balance(@recipient.address)

    # Wait past the lock (with margin), then execute for real.
    sleep(time_lock_seconds + 2)

    @vault_before     = connection.get_balance(@vault_address)
    @recipient_before = connection.get_balance(@recipient.address)

    execute_tx = program.execute_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { execute_tx.signature }

    @vault_after     = connection.get_balance(@vault_address)
    @recipient_after = connection.get_balance(@recipient.address)

    @proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )
    @final_status      = program.get_proposal(proposal_address: @proposal_address).status
  end

  it 'refuses to execute before the time lock has elapsed' do
    assert @early_execute_rejected
  end

  it 'moves no funds while the time lock is in force' do
    assert_equal 0, @recipient_after_early
  end

  it 'credits the recipient once the time lock has elapsed' do
    assert_equal @recipient_before + transfer_amount, @recipient_after
  end

  it 'debits the vault once the time lock has elapsed' do
    assert_equal @vault_before - transfer_amount, @vault_after
  end

  it 'marks the proposal executed after the delayed execution' do
    assert_equal :executed, @final_status
  end
end
