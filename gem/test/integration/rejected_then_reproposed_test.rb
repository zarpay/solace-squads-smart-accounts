# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: a 3-of-3 treasury rejects a payment, then re-proposes
#                       and unanimously approves a corrected one.
#
# This integration test walks the full async vault-transaction lifecycle twice
# on the same smart account, telling the story of a unanimous (3-of-3) multisig
# that vetoes a first attempt and then resolves it with a second.
#
# THE ACCOUNTS
#   • A single Settings account governs the treasury. Three signers — `creator`,
#     `signer_b`, `signer_c` — each hold ALL permissions (Initiate | Vote |
#     Execute), and the threshold is 3, so EVERY voter must approve for anything
#     to execute. This is the strictest possible configuration for three signers.
#   • Funds live in the smart-account (vault) PDA derived from the Settings
#     account, not in the Settings account itself. We fund that vault once.
#   • `creator` is the only funded keypair and pays the fee for every step.
#     `signer_b` / `signer_c` never hold SOL — they only co-sign their own vote
#     transactions, which `creator` pays for. A signer that is not the fee payer
#     does not spend lamports.
#
# THE VOTE MATH (deployed program: state/proposal.rs + interface/consensus_trait.rs)
#   • A proposal becomes Approved when approved.len() >= threshold.
#   • A proposal becomes Rejected when rejected.len() >= cutoff, where
#       cutoff = num_voters - threshold + 1.
#     Here num_voters = 3 and threshold = 3, so cutoff = 3 - 3 + 1 = 1: a SINGLE
#     rejection is enough to veto the proposal outright.
#   • A Proposal account is 1:1 with its Transaction (both derived from the same
#     transaction index), and Rejected is a TERMINAL state. You cannot re-open or
#     re-vote a rejected proposal. To "re-propose" you must close the rejected
#     transaction + proposal and create a brand-new transaction at the next index.
#
# THE STORY (each step below is its own confirmed on-chain transaction)
#   1. createTransaction  — store a vault → recipient transfer as index 1.
#   2. createProposal     — open voting (starts Active).
#   3. rejectProposal     — `creator` alone vetoes it (cutoff is 1) → Rejected.
#   4. closeTransaction   — reclaim the rent of the dead transaction + proposal.
#   5. createTransaction  — store the corrected transfer as index 2.
#   6. createProposal     — open voting on the re-proposal.
#   7. approveProposal ×3 — creator, then signer_b, then signer_c. Not Approved
#                           until the THIRD vote, because threshold is 3.
#   8. executeTransaction — the vault PDA signs the transfer via CPI; funds move.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: reject then re-propose (3-of-3)' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  # `creator` is funded at bootstrap and pays every transaction fee in this test.
  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:vault_funding)   { 1_000_000_000 }
  let(:transfer_amount) { 250_000_000 }

  before(:all) do
    # The two co-signers are throwaway keypairs: they are members of the smart
    # account and must SIGN their votes, but they never pay fees, so they need no
    # SOL of their own.
    @signer_b = Solace::Keypair.generate
    @signer_c = Solace::Keypair.generate

    # A 3-of-3 autonomous smart account. Autonomous (no settings_authority) is
    # irrelevant to vault transactions — it simply means no single key can
    # reconfigure the account out-of-band — but it keeps the story self-contained.
    identity = create_smart_account(
      program,
      payer:     creator,
      creator:,
      threshold: 3,
      signers:   [
        signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
        signer_klass.new(pubkey: @signer_b.address, permission: permissions::ALL),
        signer_klass.new(pubkey: @signer_c.address, permission: permissions::ALL)
      ]
    )

    @settings_address = identity.settings_address
    @vault_address    = identity.smart_account_address

    # Fund the vault once. Only the second (re-proposed) transfer ever executes,
    # so the vault needs to cover a single transfer plus fee-less rent headroom.
    fund_account(connection, @vault_address, vault_funding)

    @recipient = Solace::Keypair.generate

    # ── Attempt #1: the payment the group decides to veto ──────────────────────

    # Step 1 — store the transfer as transaction index 1.
    create_v1 = program.create_transaction(
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
    connection.wait_for_confirmed_signature { create_v1.signature }

    # Step 2 — open voting (a non-draft proposal starts Active).
    propose_v1 = program.create_proposal(
      payer:             creator,
      settings:          @settings_address,
      creator:,
      rent_payer:        creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { propose_v1.signature }

    # Step 3 — a single rejection vetoes it. cutoff = num_voters(3) - threshold(3)
    # + 1 = 1, so `creator` rejecting alone drives the proposal to Rejected.
    reject_v1 = program.reject_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { reject_v1.signature }

    @v1_proposal_address,    = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )
    @v1_transaction_address, = program.get_transaction_address(
      settings_address:  @settings_address,
      transaction_index: 1
    )
    @v1_status               = program.get_proposal(proposal_address: @v1_proposal_address).status

    # Step 4 — the rejected proposal is terminal, so the transaction can never
    # execute. Close both accounts and reclaim their rent to the creator.
    close_v1 = program.close_transaction(
      payer:             creator,
      settings:          @settings_address,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { close_v1.signature }

    @v1_transaction_after = connection.get_account_info(@v1_transaction_address)
    @v1_proposal_after    = connection.get_account_info(@v1_proposal_address)

    # ── Attempt #2: the corrected payment the group unanimously approves ────────

    # Step 5 — store the corrected transfer. create_transaction reads the
    # settings' current transaction_index (now 1) and stores this at index 2.
    create_v2 = program.create_transaction(
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
    connection.wait_for_confirmed_signature { create_v2.signature }

    # Step 6 — open voting on the re-proposal.
    propose_v2 = program.create_proposal(
      payer:             creator,
      settings:          @settings_address,
      creator:,
      rent_payer:        creator,
      transaction_index: 2
    )
    connection.wait_for_confirmed_signature { propose_v2.signature }

    @v2_proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 2
    )

    # Step 7 — collect approvals. Each approve is its own transaction signed by
    # the voting member (co-signed for free by `creator`, the fee payer). With
    # threshold 3 the proposal stays Active until the third and final approval.
    [creator, @signer_b].each do |voter|
      approve = program.approve_proposal(
        payer:             creator,
        settings:          @settings_address,
        signer:            voter,
        transaction_index: 2
      )
      connection.wait_for_confirmed_signature { approve.signature }
    end

    # Snapshot after only two of three approvals: not yet Approved.
    @v2_status_after_two = program.get_proposal(proposal_address: @v2_proposal_address).status

    approve_c = program.approve_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            @signer_c,
      transaction_index: 2
    )
    connection.wait_for_confirmed_signature { approve_c.signature }

    @v2_status = program.get_proposal(proposal_address: @v2_proposal_address).status

    # Step 8 — execute. The program signs the inner transfer AS the vault PDA via
    # CPI (the vault is the message's only "signer" but is exempt from signing the
    # outer transaction). `creator` holds Execute permission and submits it.
    @vault_before     = connection.get_balance(@vault_address)
    @recipient_before = connection.get_balance(@recipient.address)

    execute_v2 = program.execute_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 2
    )
    connection.wait_for_confirmed_signature { execute_v2.signature }

    @vault_after        = connection.get_balance(@vault_address)
    @recipient_after    = connection.get_balance(@recipient.address)
    @v2_status_final    = program.get_proposal(proposal_address: @v2_proposal_address).status
  end

  it 'vetoes the first attempt on a single rejection (cutoff is 1 for 3-of-3)' do
    assert_equal :rejected, @v1_status
  end

  it 'closes the rejected transaction account' do
    assert_nil @v1_transaction_after
  end

  it 'closes the rejected proposal account' do
    assert_nil @v1_proposal_after
  end

  it 'keeps the re-proposal Active until the third (final) approval' do
    assert_equal :active, @v2_status_after_two
  end

  it 'approves the re-proposal once all three signers have voted' do
    assert_equal :approved, @v2_status
  end

  it 'credits the recipient by the transfer amount on execution' do
    assert_equal @recipient_before + transfer_amount, @recipient_after
  end

  it 'debits the vault by the transfer amount on execution' do
    assert_equal @vault_before - transfer_amount, @vault_after
  end

  it 'marks the re-proposal executed' do
    assert_equal :executed, @v2_status_final
  end
end
