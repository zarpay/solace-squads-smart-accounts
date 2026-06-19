# frozen_string_literal: true

require_relative '../test_helper'

# Integration tests for race-free ("windowed") smart account creation:
# create_smart_account with `window > 1` offers a window of candidate settings
# PDAs, the program picks whichever matches the freshly incremented counter, and
# get_created_smart_account_event resolves which one it chose. Exercised against
# the local validator running the cloned mainnet program.
describe 'windowed smart account creation' do
  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:creator) { fixtures.load_keypair('creator') }
  let(:payer) { fixtures.load_keypair('payer') }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { Solace::Programs::SquadsSmartAccount.new(connection:) }

  let(:window) { 20 }

  # A 1-of-1 signer set controlled by the creator.
  def creator_signers
    [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
  end

  describe '#next_smart_account_candidates' do
    before(:all) do
      @start_seed  = program.get_program_config.smart_account_index + 1
      @candidates  = program.next_smart_account_candidates(count: window)
    end

    it 'returns the requested number of candidates' do
      assert_equal window, @candidates.length
    end

    it 'starts at the next seed and increments consecutively' do
      assert_equal (@start_seed...(@start_seed + window)).to_a, @candidates.map(&:settings_seed)
    end

    it 'derives each settings address from its seed' do
      expected, = program.get_settings_address(settings_seed: @candidates.first.settings_seed)
      assert_equal expected, @candidates.first.settings_address
    end
  end

  describe 'when the creator pays and no drift occurs' do
    before(:all) do
      @candidates = program.next_smart_account_candidates(count: window)

      @tx = program.create_smart_account(
        payer:         creator,
        settings_seed: @candidates.first.settings_seed,
        window:,
        creator:,
        threshold:     1,
        signers:       creator_signers
      )

      connection.wait_for_confirmed_signature { @tx.signature }

      @event  = program.get_created_smart_account_event(signature: @tx.signature)
      @winner = @candidates.find { |candidate| candidate.settings_address == @event.new_settings_pubkey }
    end

    it 'returns the signed transaction' do
      assert_kind_of Solace::Transaction, @tx
    end

    it 'resolves a settings address that was one of the offered candidates' do
      refute_nil @winner
    end

    it 'selects the first candidate when nothing consumed the index' do
      assert_equal @candidates.first.settings_address, @event.new_settings_pubkey
    end

    it 'creates the settings account on-chain at the resolved address' do
      settings = program.get_settings(settings_address: @event.new_settings_pubkey)
      assert_equal @winner.settings_seed, settings.seed
    end
  end

  describe 'when several accounts are created before the transaction lands' do
    # Number of accounts created out-of-band after the window is built but before
    # the windowed transaction lands — the program should pick the candidate at
    # exactly this offset.
    let(:drift) { 3 }

    before(:all) do
      @candidates = program.next_smart_account_candidates(count: window)

      # Simulate concurrent creations: consume the next `drift` seeds out-of-band
      # after building the window but before sending the windowed transaction.
      drift.times do
        create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 1,
          signers:   creator_signers
        )
      end

      @tx = program.create_smart_account(
        payer:         creator,
        settings_seed: @candidates.first.settings_seed,
        window:,
        creator:,
        threshold:     1,
        signers:       creator_signers
      )

      connection.wait_for_confirmed_signature { @tx.signature }

      @event    = program.get_created_smart_account_event(signature: @tx.signature)
      @expected = @candidates[drift]
    end

    it 'still succeeds despite the drift' do
      assert_kind_of Solace::Transaction, @tx
    end

    it 'skips the now-taken earlier candidates' do
      refute_equal @candidates.first.settings_address, @event.new_settings_pubkey
    end

    it 'selects the candidate at the drifted offset' do
      assert_equal @expected.settings_address, @event.new_settings_pubkey
    end

    it 'returns the expected settings seed for that candidate' do
      settings = program.get_settings(settings_address: @event.new_settings_pubkey)
      assert_equal @expected.settings_seed, settings.seed
    end

    it 'leaves the on-chain index at the created seed' do
      assert_equal @expected.settings_seed, program.get_program_config.smart_account_index
    end
  end

  describe 'when a separate sponsor pays' do
    before(:all) do
      @candidates   = program.next_smart_account_candidates(count: window)
      @creation_fee = program.get_program_config.smart_account_creation_fee

      @payer_starting_balance   = connection.get_balance(payer.address)
      @creator_starting_balance = connection.get_balance(creator.address)

      @tx = program.create_smart_account(
        payer:,
        settings_seed: @candidates.first.settings_seed,
        window:,
        creator:,
        threshold:     1,
        signers:       creator_signers
      )

      connection.wait_for_confirmed_signature { @tx.signature }

      @event            = program.get_created_smart_account_event(signature: @tx.signature)
      @settings_account = connection.get_account_info(@event.new_settings_pubkey)

      @payer_ending_balance   = connection.get_balance(payer.address)
      @creator_ending_balance = connection.get_balance(creator.address)
    end

    it 'creates the settings account at the resolved address' do
      refute_nil @settings_account
    end

    it 'deducts only the transaction fee from the sponsor' do
      # 2 signatures (payer + creator) at 5000 lamports per signature
      assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
    end

    it 'deducts the creation fee and settings rent from the creator' do
      assert_equal @creator_starting_balance - @creation_fee - @settings_account['lamports'],
                   @creator_ending_balance
    end
  end
end
