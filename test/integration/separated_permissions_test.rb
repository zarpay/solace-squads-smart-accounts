# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: separated powers — no single signer can move money alone.
#
# Squads permissions are three independent bits that can be granted in any
# combination (see types/permissions.rb):
#   • Initiate — may CREATE a transaction and OPEN its proposal.
#   • Vote     — may APPROVE / reject / cancel a proposal.
#   • Execute  — may EXECUTE an approved transaction.
#
# This test builds the textbook "separation of duties" treasury: three members,
# each holding exactly ONE of the three permissions, so the full lifecycle can
# only complete if all three cooperate, each acting strictly within their lane.
# It walks every gate and proves two things at each step:
#   (1) a member WITHOUT the required permission is rejected (program error
#       Unauthorized → an RPC error at submission), and
#   (2) the member WITH the required permission succeeds.
# Only the aggregate — proposer THEN voter THEN executor — moves the funds.
#
# THE MEMBERS
#   • `proposer`  — Initiate only.
#   • `voter`     — Vote only.
#   • `executor`  — Execute only.
#   They are throwaway keypairs and never hold SOL. The funded `payer` fixture
#   pays every fee and the account rent, and co-signs each step; the acting
#   member co-signs to prove their authority. (A member that is not the fee
#   payer spends no lamports.)
#
# THE THRESHOLD
#   Only `voter` holds Vote, so num_voters = 1 and the threshold must be 1: a
#   single approval from `voter` carries a proposal to Approved.
#
# WHY THE NEGATIVE CHECKS ARE INTERLEAVED (not deferred to separate tests)
#   The permission failures must be attempted at the exact moment they are
#   relevant — e.g. a wrong-party `createProposal` has to run BEFORE the proposer
#   creates the proposal, otherwise it would fail because the proposal already
#   exists rather than for lack of Initiate. So the whole ordered sequence runs
#   in `before(:all)`, recording whether each forbidden attempt was rejected, and
#   the `it` blocks assert those recordings plus the final happy-path effects.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: separated permissions (Initiate / Vote / Execute)' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  # `payer` is funded at bootstrap; it pays every fee and rent in this test.
  let(:payer) { fixtures.load_keypair('payer') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:vault_funding)   { 1_000_000_000 }
  let(:transfer_amount) { 250_000_000 }

  # Runs the block and reports whether the program rejected it at submission.
  # Used to assert that a member lacking a permission cannot perform a step.
  def rpc_rejected?
    yield
    false
  rescue Solace::Errors::RPCError
    true
  end

  # Stores a vault → recipient transfer signed by `creator` (the acting member),
  # with `payer` paying the fee and rent. Returns the sent transaction.
  def create_transfer(creator:)
    program.create_transaction(
      payer:,
      settings:     @settings_address,
      creator:,
      rent_payer:   payer,
      instructions: [
        Solace::Composers::SystemProgramTransferComposer.new(
          from:     @vault_address,
          to:       @recipient.address,
          lamports: transfer_amount
        )
      ]
    )
  end

  before(:all) do
    @proposer = Solace::Keypair.generate
    @voter    = Solace::Keypair.generate
    @executor = Solace::Keypair.generate

    # Each member holds exactly one permission. The on-chain invariant requires at
    # least one proposer, one voter, and one executor — satisfied here one-each.
    # The `creator` of the account pays the creation fee + settings rent and need
    # NOT be a governance member, so the funded `payer` fixture bootstraps it: the
    # entity paying the bills holds no Initiate/Vote/Execute power of its own.
    identity = create_smart_account(
      program,
      payer:,
      creator:   payer,
      threshold: 1, # only `voter` can vote, so the threshold can only be 1
      signers:   [
        signer_klass.new(pubkey: @proposer.address, permission: permissions::INITIATE),
        signer_klass.new(pubkey: @voter.address, permission: permissions::VOTE),
        signer_klass.new(pubkey: @executor.address, permission: permissions::EXECUTE)
      ]
    )

    @settings_address = identity.settings_address
    @vault_address    = identity.smart_account_address
    fund_account(connection, @vault_address, vault_funding)

    @recipient = Solace::Keypair.generate

    # ── Gate 1: creating a transaction requires Initiate ───────────────────────
    # The voter holds Vote, not Initiate, so it cannot author a transaction.
    @create_without_initiate_rejected = rpc_rejected? { create_transfer(creator: @voter) }

    # The proposer holds Initiate → the transaction is stored at index 1.
    create_tx = create_transfer(creator: @proposer)
    connection.wait_for_confirmed_signature { create_tx.signature }

    # ── Gate 2: opening the proposal also requires Initiate ────────────────────
    # The executor holds Execute, not Initiate, so it cannot open the proposal.
    # (Attempted BEFORE the proposer opens it, so the failure is Unauthorized and
    # not "proposal already exists".)
    @propose_without_initiate_rejected = rpc_rejected? do
      program.create_proposal(
        payer:,
        settings:          @settings_address,
        creator:           @executor,
        rent_payer:        payer,
        transaction_index: 1
      )
    end

    # The proposer opens the proposal (starts Active).
    propose_tx = program.create_proposal(
      payer:,
      settings:          @settings_address,
      creator:           @proposer,
      rent_payer:        payer,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { propose_tx.signature }

    @proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )

    # ── Gate 3: approving requires Vote ────────────────────────────────────────
    # The proposer holds Initiate, not Vote, so its approval is rejected.
    @approve_without_vote_rejected = rpc_rejected? do
      program.approve_proposal(
        payer:,
        settings:          @settings_address,
        signer:            @proposer,
        transaction_index: 1
      )
    end

    # The voter holds Vote → one approval reaches the threshold of 1 → Approved.
    approve_tx = program.approve_proposal(
      payer:,
      settings:          @settings_address,
      signer:            @voter,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { approve_tx.signature }

    @status_after_approve = program.get_proposal(proposal_address: @proposal_address).status

    # ── Gate 4: executing requires Execute ─────────────────────────────────────
    # The voter holds Vote, not Execute, so it cannot execute the approved tx.
    @execute_without_execute_rejected = rpc_rejected? do
      program.execute_transaction(
        payer:,
        settings:          @settings_address,
        signer:            @voter,
        transaction_index: 1
      )
    end

    # The executor holds Execute → the transfer finally runs and funds move.
    @vault_before     = connection.get_balance(@vault_address)
    @recipient_before = connection.get_balance(@recipient.address)

    execute_tx = program.execute_transaction(
      payer:,
      settings:          @settings_address,
      signer:            @executor,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { execute_tx.signature }

    @vault_after     = connection.get_balance(@vault_address)
    @recipient_after = connection.get_balance(@recipient.address)
    @final_status    = program.get_proposal(proposal_address: @proposal_address).status
  end

  it 'rejects creating a transaction without the Initiate permission' do
    assert @create_without_initiate_rejected
  end

  it 'rejects opening a proposal without the Initiate permission' do
    assert @propose_without_initiate_rejected
  end

  it 'rejects approving without the Vote permission' do
    assert @approve_without_vote_rejected
  end

  it 'approves once the Vote-holding member signs' do
    assert_equal :approved, @status_after_approve
  end

  it 'rejects executing without the Execute permission' do
    assert @execute_without_execute_rejected
  end

  it 'credits the recipient once the Execute-holding member runs it' do
    assert_equal @recipient_before + transfer_amount, @recipient_after
  end

  it 'debits the vault by the transfer amount on execution' do
    assert_equal @vault_before - transfer_amount, @vault_after
  end

  it 'marks the proposal executed only after all three roles have acted' do
    assert_equal :executed, @final_status
  end
end
