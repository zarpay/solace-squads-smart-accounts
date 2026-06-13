# frozen_string_literal: true

require_relative '../test_helper'

# ─────────────────────────────────────────────────────────────────────────────
# GOVERNANCE LIFECYCLE: a smart account rewrites its own rules over time.
#
# Settings transactions are how an AUTONOMOUS smart account (one with no external
# settings authority) governs CHANGES TO ITSELF — adding/removing signers,
# changing the threshold, the time lock, spending limits. Like vault transactions
# they go through the full propose → vote → execute lifecycle, except the thing
# being executed is a batch of SettingsActions applied to the Settings account
# rather than a transfer out of the vault.
#
# This test tells the story of a multisig MATURING its governance: it begins as a
# solo 1-of-1 account, votes itself into a 2-of-3, and then — now bound by the
# stricter 2-of-3 rule it just enacted — votes itself into a unanimous 3-of-3.
# The point it proves: a threshold change takes effect for EVERY SUBSEQUENT
# proposal, including the very next one.
#
# THE ACCOUNTS
#   • One autonomous Settings account. `creator` is the founding signer (ALL
#     permissions) and the universal fee payer. `signer_b` / `signer_c` are
#     throwaway keypairs — added as members along the way, and used to cast the
#     extra votes the rising threshold demands. They never hold SOL; `creator`
#     pays every fee and co-signs each vote transaction.
#   • No vault funding is needed: nothing moves out of the vault here, this is
#     pure self-governance. `rent_payer: creator` covers the Settings account
#     REALLOCATION that adding signers requires (the account grows to hold them).
#
# THE VOTE MATH
#   • Approved when approved.len() >= threshold. The threshold in force is the one
#     stored on the Settings account AT THE MOMENT OF VOTING — so a change applied
#     by one settings transaction governs the approval of the next.
#
# THE STORY (each step is its own confirmed on-chain transaction)
#   Settings transaction #1 (decided under the founding 1-of-1 rule):
#     create → propose → approve(creator) → Approved → execute
#       actions: AddSigner(b), AddSigner(c), ChangeThreshold(2)
#     Result: the account is now a 2-of-3.
#   Settings transaction #2 (decided under the NEW 2-of-3 rule):
#     create → propose → approve(creator)  ⟶ still Active (1 of 2 is not enough!)
#                      → approve(signer_b) ⟶ Approved → execute
#       actions: ChangeThreshold(3)
#     Result: the account is now a unanimous 3-of-3.
# ─────────────────────────────────────────────────────────────────────────────
describe 'governance lifecycle: an account evolves its own signers and threshold' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  let(:creator) { fixtures.load_keypair('creator') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  before(:all) do
    @signer_b = Solace::Keypair.generate
    @signer_c = Solace::Keypair.generate

    # Founding configuration: a solo 1-of-1 autonomous account. Only settings
    # transactions on AUTONOMOUS accounts are permitted by the program, so we do
    # not set a settings_authority (which would make it "controlled").
    identity = create_smart_account(
      program,
      payer:     creator,
      creator:,
      threshold: 1,
      signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
    )

    @settings_address = identity.settings_address

    # ── Settings transaction #1: 1-of-1 → 2-of-3 ───────────────────────────────
    # Decided while the account is still 1-of-1, so `creator`'s lone approval is
    # enough to pass it. Three actions are applied atomically: two new signers and
    # the threshold raised to 2.
    create_1 = program.create_settings_transaction(
      payer:      creator,
      settings:   @settings_address,
      creator:,
      rent_payer: creator,
      actions:    [
        action_klass.add_signer(pubkey: @signer_b.address, permission: permissions::ALL),
        action_klass.add_signer(pubkey: @signer_c.address, permission: permissions::ALL),
        action_klass.change_threshold(2)
      ]
    )
    connection.wait_for_confirmed_signature { create_1.signature }

    propose_1 = program.create_proposal(
      payer:             creator,
      settings:          @settings_address,
      creator:,
      rent_payer:        creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { propose_1.signature }

    approve_1 = program.approve_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1
    )
    connection.wait_for_confirmed_signature { approve_1.signature }

    # Executing applies the actions to the Settings account. `rent_payer` funds
    # the reallocation needed to store the two new signers.
    execute_1 = program.execute_settings_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 1,
      rent_payer:        creator
    )
    connection.wait_for_confirmed_signature { execute_1.signature }

    @settings_after_1 = program.get_settings(settings_address: @settings_address)

    # ── Settings transaction #2: 2-of-3 → 3-of-3 ───────────────────────────────
    # Now decided under the rule enacted above: the account is a 2-of-3, so this
    # proposal needs TWO approvals. We prove the new rule is live by checking the
    # proposal is still Active after a single approval.
    create_2 = program.create_settings_transaction(
      payer:      creator,
      settings:   @settings_address,
      creator:,
      rent_payer: creator,
      actions:    [action_klass.change_threshold(3)]
    )
    connection.wait_for_confirmed_signature { create_2.signature }

    propose_2 = program.create_proposal(
      payer:             creator,
      settings:          @settings_address,
      creator:,
      rent_payer:        creator,
      transaction_index: 2
    )
    connection.wait_for_confirmed_signature { propose_2.signature }

    @tx2_proposal_address, = program.get_proposal_address(
      settings_address:  @settings_address,
      transaction_index: 2
    )

    # First approval — under the 2-of-3 rule this is NOT enough.
    approve_2a = program.approve_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 2
    )
    connection.wait_for_confirmed_signature { approve_2a.signature }

    @tx2_status_after_one = program.get_proposal(proposal_address: @tx2_proposal_address).status

    # Second approval — reaches the threshold of 2 → Approved.
    approve_2b = program.approve_proposal(
      payer:             creator,
      settings:          @settings_address,
      signer:            @signer_b,
      transaction_index: 2
    )
    connection.wait_for_confirmed_signature { approve_2b.signature }

    @tx2_status = program.get_proposal(proposal_address: @tx2_proposal_address).status

    execute_2 = program.execute_settings_transaction(
      payer:             creator,
      settings:          @settings_address,
      signer:            creator,
      transaction_index: 2,
      rent_payer:        creator
    )
    connection.wait_for_confirmed_signature { execute_2.signature }

    @settings_after_2 = program.get_settings(settings_address: @settings_address)
  end

  it 'adds both new signers in the first settings transaction' do
    assert_equal 3, @settings_after_1.signers.length
  end

  it 'includes the added signer pubkeys in the signer set' do
    assert_includes @settings_after_1.signers.map(&:pubkey), @signer_b.address
  end

  it 'raises the threshold to 2 in the first settings transaction' do
    assert_equal 2, @settings_after_1.threshold
  end

  it 'keeps the second proposal Active after one approval (the new 2-of-3 rule is enforced)' do
    assert_equal :active, @tx2_status_after_one
  end

  it 'approves the second proposal once two signers have voted' do
    assert_equal :approved, @tx2_status
  end

  it 'raises the threshold to 3 in the second settings transaction' do
    assert_equal 3, @settings_after_2.threshold
  end
end
