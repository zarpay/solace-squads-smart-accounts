# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: a settings change invalidates in-flight proposals.
#
# A multisig must not let a payment that was queued under one set of rules slip
# through after the rules change. Squads enforces this with a "stale" watermark:
# AddSigner, RemoveSigner, ChangeThreshold and SetTimeLock all call
# invalidate_prior_transactions(), which sets
#     settings.stale_transaction_index = settings.transaction_index
# at the moment the settings change EXECUTES. Every transaction whose index is
# <= that watermark is then considered stale.
#
# The program treats stale proposals ASYMMETRICALLY, and this test pins down both
# halves of that asymmetry on the same account:
#
#   • An ACTIVE proposal that becomes stale can no longer be voted on. The vote
#     handler requires transaction_index > stale_transaction_index, so approving
#     it fails with StaleProposal. (The queued-but-undecided payment is killed.)
#
#   • A vault proposal that was already APPROVED before going stale can STILL be
#     executed — the vault execute handler deliberately does NOT check staleness
#     ("stale transaction proposals CAN be executed if they were approved before
#     becoming stale"). A decision the group already reached is honored.
#
# THE STORY (autonomous 1-of-1; `creator` holds ALL permissions, threshold 1)
#   tx#1  vault → recipient_a : created, proposed, and APPROVED (Approved).
#   tx#2  vault → recipient_b : created and proposed, left ACTIVE (undecided).
#   tx#3  settings AddSigner  : created, proposed, approved, EXECUTED — this is
#                               the rule change; it sets stale_transaction_index
#                               to 3, so tx#1 and tx#2 (indexes 1 and 2) are now
#                               stale.
#   Then we observe:
#   • approving tx#2 (stale + Active)   → rejected with StaleProposal.
#   • executing tx#1 (stale + Approved) → SUCCEEDS; recipient_a is paid.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: a settings change invalidates in-flight proposals' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:vault_funding) { 1_000_000_000 }
  let(:amount_a) { 200_000_000 }
  let(:amount_b) { 200_000_000 }

  # Runs the block and reports whether the program rejected it at submission.
  def rpc_rejected?
    yield
    false
  rescue Solace::Errors::RPCError
    true
  end

  # Stores a vault → recipient transfer and waits; returns nothing (the index is
  # implied by call order: each create takes settings.transaction_index + 1).
  def store_transfer(recipient:, lamports:)
    tx = program.create_transaction(
      payer:        creator,
      settings:     @settings_address,
      creator:,
      rent_payer:   creator,
      instructions: [
        Solace::Composers::SystemProgramTransferComposer.new(
          from:     @vault_address,
          to:       recipient.address,
          lamports:
        )
      ]
    )
    connection.wait_for_confirmed_signature { tx.signature }
  end

  # Opens a proposal for the given transaction index and waits.
  def open_proposal(transaction_index:)
    tx = program.create_proposal(
      payer:             creator,
      settings:          @settings_address,
      creator:,
      rent_payer:        creator,
      transaction_index:
    )
    connection.wait_for_confirmed_signature { tx.signature }
  end

  # Approves the given transaction index (creator) and waits.
  def approve(transaction_index:)
    tx = program.approve_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index:
    )
    connection.wait_for_confirmed_signature { tx.signature }
  end

  before(:all) do
    @signer_b = Solace::Keypair.generate

    # Autonomous so the account can govern itself with settings transactions.
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

    # tx#1 — queue payment A and DECIDE it (Approved) while the rules still hold.
    store_transfer(recipient: @recipient_a, lamports: amount_a)
    open_proposal(transaction_index: 1)
    approve(transaction_index: 1)

    # tx#2 — queue payment B but leave it undecided (Active).
    store_transfer(recipient: @recipient_b, lamports: amount_b)
    open_proposal(transaction_index: 2)

    # tx#3 — the rule change. Adding a signer bumps stale_transaction_index to 3
    # when it executes, retroactively staling tx#1 and tx#2.
    create_settings = program.create_settings_transaction(
      payer:      creator,
      settings:   @settings_address,
      creator:,
      rent_payer: creator,
      actions:    [action_klass.add_signer(pubkey: @signer_b.address, permission: permissions::ALL)]
    )
    connection.wait_for_confirmed_signature { create_settings.signature }

    open_proposal(transaction_index: 3)
    approve(transaction_index: 3)

    execute_settings = program.execute_settings_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 3,
      rent_payer:        creator
    )
    connection.wait_for_confirmed_signature { execute_settings.signature }

    @settings_after_change = program.get_settings(settings_address: @settings_address)

    # The membership change is live: signer_b is now a member, confirming the
    # rule change (and therefore the stale watermark) took effect.

    @tx2_proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 2
    )

    # Observation 1 — tx#2 is now stale AND still Active: it cannot be voted on.
    @approve_stale_active_rejected = rpc_rejected? { approve(transaction_index: 2) }
    @tx2_status                    = program.get_proposal(proposal_address: @tx2_proposal_address).status

    # Observation 2 — tx#1 is stale but was Approved before the change, so the
    # vault execute handler still honors it.
    @vault_before       = connection.get_balance(@vault_address)
    @recipient_a_before = connection.get_balance(@recipient_a.address)

    execute_tx1 = program.execute_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { execute_tx1.signature }

    @vault_after        = connection.get_balance(@vault_address)
    @recipient_a_after  = connection.get_balance(@recipient_a.address)

    @tx1_proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )
    @tx1_status            = program.get_proposal(proposal_address: @tx1_proposal_address).status
  end

  it 'applies the membership change that sets the stale watermark' do
    assert_equal 2, @settings_after_change.signers.length
  end

  it 'refuses to approve a proposal that became stale while still Active' do
    assert @approve_stale_active_rejected
  end

  it 'leaves the staled, undecided proposal stuck in Active' do
    assert_equal :active, @tx2_status
  end

  it 'still executes a proposal that was Approved before it became stale' do
    assert_equal :executed, @tx1_status
  end

  it 'pays the recipient of the approved-before-stale transaction' do
    assert_equal @recipient_a_before + amount_a, @recipient_a_after
  end

  it 'debits the vault only for the executed transaction' do
    assert_equal @vault_before - amount_a, @vault_after
  end
end
