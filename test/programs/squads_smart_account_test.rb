# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::Programs::SquadsSmartAccount do
  let(:klass) { Solace::Programs::SquadsSmartAccount }

  let(:fixtures)     { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions)  { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program)    { klass.new(connection:) }
  let(:creator)    { fixtures.load_keypair('creator') }

  # Fixtures
  let(:payer) { fixtures.load_keypair('payer') }

  describe '#initialize' do
    it 'assigns connection' do
      assert_equal connection, program.connection
    end

    it 'assigns the Squads Smart Account program id' do
      assert_equal Solace::SquadsSmartAccounts::PROGRAM_ID, program.program_id
    end
  end

  describe '.get_settings_address' do
    let(:settings_seed) { 42 }

    it 'derives the settings PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', 'settings', Solace::Utils::Codecs.encode_le_u128(settings_seed).bytes],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_settings_address(settings_seed:)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'is available as an instance method' do
      assert_equal klass.get_settings_address(settings_seed:),
                   program.get_settings_address(settings_seed:)
    end
  end

  describe '.get_smart_account_address' do
    let(:settings_address) { klass.get_settings_address(settings_seed: 42).first }

    it 'derives the vault PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', settings_address, 'smart_account', [0]],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_smart_account_address(settings_address:)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'defaults account_index to 0' do
      assert_equal klass.get_smart_account_address(settings_address:, account_index: 0),
                   klass.get_smart_account_address(settings_address:)
    end

    it 'derives different addresses for different account indexes' do
      address_zero, = klass.get_smart_account_address(settings_address:)
      address_one,  = klass.get_smart_account_address(settings_address:, account_index: 1)

      refute_equal address_zero, address_one
    end

    it 'is available as an instance method' do
      assert_equal klass.get_smart_account_address(settings_address:),
                   program.get_smart_account_address(settings_address:)
    end
  end

  describe '.get_spending_limit_address' do
    let(:settings_address) { klass.get_settings_address(settings_seed: 42).first }
    let(:seed) { Solace::Keypair.generate }

    it 'derives the spending limit PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', settings_address, 'spending_limit', seed.address],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_spending_limit_address(settings_address:, seed:)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'is available as an instance method' do
      assert_equal klass.get_spending_limit_address(settings_address:, seed:),
                   program.get_spending_limit_address(settings_address:, seed:)
    end
  end

  describe '#get_spending_limit' do
    it 'raises when no spending limit account exists at the address' do
      missing = Solace::Keypair.generate.address

      error = assert_raises(RuntimeError) { program.get_spending_limit(spending_limit_address: missing) }
      assert_match(/not found/, error.message)
    end
  end

  describe '#get_program_config' do
    it 'fetches and deserializes the global program config' do
      config = program.get_program_config

      assert_kind_of Solace::SquadsSmartAccounts::ProgramConfig, config
      assert_kind_of Integer, config.smart_account_index
      assert Solace::Utils::Codecs.valid_base58?(config.treasury)
    end
  end

  describe '#next_smart_account' do
    it 'returns the identity of the next smart account' do
      identity = program.next_smart_account

      assert_kind_of Solace::SquadsSmartAccounts::SmartAccountIdentity, identity
      assert_equal program.get_program_config.smart_account_index + 1, identity.settings_seed
    end
  end

  describe '#create_smart_account' do
    describe 'when the creator pays for the transaction' do
      before(:all) do
        @identity = program.next_smart_account

        @tx = program.create_smart_account(
          payer:         creator,
          settings_seed: @identity.settings_seed,
          creator:,
          threshold:     1,
          signers:       [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'creates the settings account at the identity address' do
        settings = program.get_settings(settings_address: @identity.settings_address)

        assert_equal @identity.settings_seed, settings.seed
        assert_equal 1, settings.threshold
      end

      it 'increments the on-chain smart account index to the identity seed' do
        assert_equal @identity.settings_seed, program.get_program_config.smart_account_index
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @identity     = program.next_smart_account
        @creation_fee = program.get_program_config.smart_account_creation_fee

        @payer_starting_balance   = connection.get_balance(payer.address)
        @creator_starting_balance = connection.get_balance(creator.address)

        @tx = program.create_smart_account(
          payer:,
          settings_seed: @identity.settings_seed,
          creator:,
          threshold:     1,
          signers:       [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings_account = connection.get_account_info(@identity.settings_address)

        @payer_ending_balance   = connection.get_balance(payer.address)
        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'creates the settings account at the identity address' do
        settings = program.get_settings(settings_address: @identity.settings_address)

        assert_equal @identity.settings_seed, settings.seed
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

  describe '#compose_create_smart_account' do
    it 'returns a TransactionComposer ready for a fee payer' do
      composer = program.compose_create_smart_account(
        settings_seed: program.next_smart_account.settings_seed,
        creator:,
        threshold:     1,
        signers:       [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      assert_kind_of Solace::TransactionComposer, composer
    end
  end

  describe '#execute_transaction_sync' do
    let(:vault_funding)   { 1_000_000_000 }
    let(:transfer_amount) { 250_000_000 }

    describe 'when the signer pays for the transaction' do
      before(:all) do
        # Create a 1-of-1 smart account and fund its default vault.
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 1,
          signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        signature = connection.request_airdrop(@identity.smart_account_address, vault_funding)
        connection.wait_for_confirmed_signature { signature['result'] }

        # Transfer SOL out of the vault through the program method.
        @recipient = Solace::Keypair.generate

        @tx = program.execute_transaction_sync(
          payer:         creator,
          settings:      @identity.settings_address,
          smart_account: @identity.smart_account_address,
          signers:       [creator],
          instructions:  [
            Solace::Composers::SystemProgramTransferComposer.new(
              from:     @identity.smart_account_address,
              to:       @recipient.address,
              lamports: transfer_amount
            )
          ]
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'transfers the amount out of the vault to the recipient' do
        assert_equal transfer_amount, connection.get_balance(@recipient.address)
        assert_equal vault_funding - transfer_amount,
                     connection.get_balance(@identity.smart_account_address)
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        # Create a 1-of-1 smart account and fund its default vault.
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 1,
          signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        signature = connection.request_airdrop(@identity.smart_account_address, vault_funding)
        connection.wait_for_confirmed_signature { signature['result'] }

        @recipient = Solace::Keypair.generate

        @payer_starting_balance   = connection.get_balance(payer.address)
        @creator_starting_balance = connection.get_balance(creator.address)

        # The sponsor pays the fee; the creator only co-signs for consensus.
        @tx = program.execute_transaction_sync(
          payer:,
          settings:      @identity.settings_address,
          smart_account: @identity.smart_account_address,
          signers:       [creator],
          instructions:  [
            Solace::Composers::SystemProgramTransferComposer.new(
              from:     @identity.smart_account_address,
              to:       @recipient.address,
              lamports: transfer_amount
            )
          ]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @payer_ending_balance   = connection.get_balance(payer.address)
        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'transfers the amount out of the vault to the recipient' do
        assert_equal transfer_amount, connection.get_balance(@recipient.address)
        assert_equal vault_funding - transfer_amount,
                     connection.get_balance(@identity.smart_account_address)
      end

      it 'deducts only the transaction fee from the sponsor' do
        # 2 signatures (payer + creator) at 5000 lamports per signature
        assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
      end

      it 'deducts nothing from the consensus signer' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end
  end

  describe '#compose_execute_transaction_sync' do
    it 'returns a TransactionComposer ready for a fee payer' do
      identity = program.next_smart_account

      composer = program.compose_execute_transaction_sync(
        settings:      identity.settings_address,
        smart_account: identity.smart_account_address,
        signers:       [creator.address],
        instructions:  [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     identity.smart_account_address,
            to:       Solace::Keypair.generate.address,
            lamports: 1
          )
        ]
      )

      assert_kind_of Solace::TransactionComposer, composer
    end
  end

  describe '#get_settings' do
    it 'raises when no settings account exists at the address' do
      missing = Solace::Keypair.generate.address

      error = assert_raises(RuntimeError) { program.get_settings(settings_address: missing) }
      assert_match(/not found/, error.message)
    end
  end

  describe '#add_signer_as_authority' do
    describe 'when the authority pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @new_signer_key = Solace::Keypair.generate

        @tx = program.add_signer_as_authority(
          payer:              creator,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         creator,
          new_signer:         signer_klass.new(
            pubkey:     @new_signer_key.address,
            permission: permissions::VOTE
          )
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'adds the signer with its granted permissions' do
        added = @settings.signers.find { |signer| signer.pubkey == @new_signer_key.address }

        refute_nil added
        assert_equal permissions::VOTE, added.permission
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @new_signer_key = Solace::Keypair.generate

        @payer_starting_balance   = connection.get_balance(payer.address)
        @creator_starting_balance = connection.get_balance(creator.address)

        # The sponsor pays the fee AND the realloc rent; the authority only signs.
        @tx = program.add_signer_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         payer,
          new_signer:         signer_klass.new(
            pubkey:     @new_signer_key.address,
            permission: permissions::VOTE
          )
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)

        @payer_ending_balance   = connection.get_balance(payer.address)
        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'adds the signer with its granted permissions' do
        added = @settings.signers.find { |signer| signer.pubkey == @new_signer_key.address }

        refute_nil added
        assert_equal permissions::VOTE, added.permission
      end

      it 'deducts nothing from the authority' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end

      it 'deducts the transaction fee and realloc rent from the sponsor' do
        # 2 signatures (payer + authority) at 5000 lamports per signature,
        # plus whatever realloc rent the settings account required.
        fee = 2 * 5000

        assert_operator @payer_ending_balance, :<=, @payer_starting_balance - fee
      end
    end

    describe 'when the authority is not a member of the signer set' do
      before(:all) do
        # The authority is a fresh, unfunded keypair: it only signs — the
        # sponsor pays all fees and rent. It appears nowhere in the signer set.
        @authority = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: @authority.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @new_signer_key = Solace::Keypair.generate

        @tx = program.add_signer_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: @authority,
          rent_payer:         payer,
          new_signer:         signer_klass.new(
            pubkey:     @new_signer_key.address,
            permission: permissions::VOTE
          )
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'adds the signer on the authority signature alone' do
        added = @settings.signers.find { |signer| signer.pubkey == @new_signer_key.address }

        refute_nil added
        assert_equal permissions::VOTE, added.permission
      end

      it 'does not include the authority in the signer set' do
        refute(@settings.signers.any? { |signer| signer.pubkey == @authority.address })
      end
    end

    describe 'when a non-authority member attempts the change' do
      before(:all) do
        # creator is a member with full permissions, but the authority is a
        # different (generated) key that never signs.
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: Solace::Keypair.generate.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )
      end

      it 'rejects the transaction with Unauthorized' do
        error = assert_raises(Solace::Errors::RPCError) do
          program.add_signer_as_authority(
            payer:              creator,
            settings:           @identity.settings_address,
            settings_authority: creator,
            rent_payer:         creator,
            new_signer:         signer_klass.new(
              pubkey:     Solace::Keypair.generate.address,
              permission: permissions::VOTE
            )
          )
        end

        # Unauthorized — error code 6005 (0x1775)
        assert_match(/0x1775/, error.message)
      end
    end
  end

  describe '#remove_signer_as_authority' do
    describe 'when the authority pays for the transaction' do
      before(:all) do
        @removed_signer_key = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: @removed_signer_key.address, permission: permissions::VOTE)
          ]
        )

        @tx = program.remove_signer_as_authority(
          payer:              creator,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         creator,
          old_signer:         @removed_signer_key.address
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'removes the signer from the set' do
        assert_equal 1, @settings.signers.length
        refute(@settings.signers.any? { |signer| signer.pubkey == @removed_signer_key.address })
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @removed_signer_key = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: @removed_signer_key.address, permission: permissions::VOTE)
          ]
        )

        @creator_starting_balance = connection.get_balance(creator.address)

        @tx = program.remove_signer_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         payer,
          old_signer:         @removed_signer_key.address
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'removes the signer from the set' do
        assert_equal 1, @settings.signers.length
        refute(@settings.signers.any? { |signer| signer.pubkey == @removed_signer_key.address })
      end

      it 'deducts nothing from the authority' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end
  end

  describe '#change_threshold_as_authority' do
    describe 'when the authority pays for the transaction' do
      before(:all) do
        second_signer = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: second_signer.address, permission: permissions::ALL)
          ]
        )

        @tx = program.change_threshold_as_authority(
          payer:              creator,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         creator,
          new_threshold:      2
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'updates the threshold' do
        assert_equal 2, @settings.threshold
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        second_signer = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: second_signer.address, permission: permissions::ALL)
          ]
        )

        @creator_starting_balance = connection.get_balance(creator.address)

        @tx = program.change_threshold_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         payer,
          new_threshold:      2
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'updates the threshold' do
        assert_equal 2, @settings.threshold
      end

      it 'deducts nothing from the authority' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end

    describe 'when the rent payer is distinct from the payer and authority' do
      before(:all) do
        second_signer = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: second_signer.address, permission: permissions::ALL)
          ]
        )

        # A fresh, unfunded keypair: it only signs as rentPayer — a threshold
        # change does not resize the settings account, so no rent is due.
        @rent_payer = Solace::Keypair.generate

        @tx = program.change_threshold_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         @rent_payer,
          new_threshold:      2
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'updates the threshold' do
        assert_equal 2, @settings.threshold
      end

      it 'charges the rent payer nothing when no realloc is needed' do
        assert_equal 0, connection.get_balance(@rent_payer.address)
      end
    end

    describe 'when the new threshold would deadlock the account' do
      before(:all) do
        # A 1-of-1 controlled account: only one voting signer exists.
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )
      end

      it 'rejects a threshold above the number of voting signers with InvalidThreshold' do
        error = assert_raises(Solace::Errors::RPCError) do
          program.change_threshold_as_authority(
            payer:              creator,
            settings:           @identity.settings_address,
            settings_authority: creator,
            rent_payer:         creator,
            new_threshold:      2
          )
        end

        # InvalidThreshold — error code 6004 (0x1774)
        assert_match(/0x1774/, error.message)
      end

      it 'rejects a zero threshold with InvalidThreshold' do
        error = assert_raises(Solace::Errors::RPCError) do
          program.change_threshold_as_authority(
            payer:              creator,
            settings:           @identity.settings_address,
            settings_authority: creator,
            rent_payer:         creator,
            new_threshold:      0
          )
        end

        # InvalidThreshold — error code 6004 (0x1774)
        assert_match(/0x1774/, error.message)
      end
    end
  end

  describe '#set_time_lock_as_authority' do
    describe 'when the authority pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @tx = program.set_time_lock_as_authority(
          payer:              creator,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         creator,
          time_lock:          900
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'updates the time lock' do
        assert_equal 900, @settings.time_lock
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @creator_starting_balance = connection.get_balance(creator.address)

        @tx = program.set_time_lock_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         payer,
          time_lock:          900
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'updates the time lock' do
        assert_equal 900, @settings.time_lock
      end

      it 'deducts nothing from the authority' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end
  end

  describe '#set_new_settings_authority_as_authority' do
    describe 'when the authority pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @new_authority = Solace::Keypair.generate

        @tx = program.set_new_settings_authority_as_authority(
          payer:                  creator,
          settings:               @identity.settings_address,
          settings_authority:     creator,
          rent_payer:             creator,
          new_settings_authority: @new_authority.address
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'stores the new settings authority' do
        assert_equal @new_authority.address, @settings.settings_authority
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @new_authority = Solace::Keypair.generate

        @creator_starting_balance = connection.get_balance(creator.address)

        @tx = program.set_new_settings_authority_as_authority(
          payer:,
          settings:               @identity.settings_address,
          settings_authority:     creator,
          rent_payer:             payer,
          new_settings_authority: @new_authority.address
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'stores the new settings authority' do
        assert_equal @new_authority.address, @settings.settings_authority
      end

      it 'deducts nothing from the authority' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end

    describe 'when renouncing the authority (nil new authority)' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @tx = program.set_new_settings_authority_as_authority(
          payer:                  creator,
          settings:               @identity.settings_address,
          settings_authority:     creator,
          rent_payer:             creator,
          new_settings_authority: nil
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'stores the default pubkey, marking the account autonomous' do
        assert_equal Solace::SquadsSmartAccounts::DEFAULT_PUBKEY, @settings.settings_authority
      end

      it 'permanently strips the old authority of its power' do
        error = assert_raises(Solace::Errors::RPCError) do
          program.set_time_lock_as_authority(
            payer:              creator,
            settings:           @identity.settings_address,
            settings_authority: creator,
            rent_payer:         creator,
            time_lock:          60
          )
        end

        # Unauthorized — error code 6005 (0x1775)
        assert_match(/0x1775/, error.message)
      end
    end
  end

  describe '#execute_settings_transaction_sync' do
    let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

    describe 'when a signer pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 1,
          signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @new_signer_key = Solace::Keypair.generate

        @tx = program.execute_settings_transaction_sync(
          payer:      creator,
          settings:   @identity.settings_address,
          signers:    [creator],
          rent_payer: creator,
          actions:    [
            action_klass.add_signer(pubkey: @new_signer_key.address, permission: permissions::VOTE)
          ]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'applies the action' do
        added = @settings.signers.find { |signer| signer.pubkey == @new_signer_key.address }

        refute_nil added
        assert_equal permissions::VOTE, added.permission
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 1,
          signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @creator_starting_balance = connection.get_balance(creator.address)

        # The sponsor pays the fee and any realloc rent; creator only co-signs.
        @tx = program.execute_settings_transaction_sync(
          payer:,
          settings:   @identity.settings_address,
          signers:    [creator],
          rent_payer: payer,
          actions:    [action_klass.set_time_lock(120)]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'applies the action' do
        assert_equal 120, @settings.time_lock
      end

      it 'deducts nothing from the co-signer' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end

    describe 'when multiple co-signers meet the threshold' do
      before(:all) do
        # A 2-of-2 account: both signers must co-sign any settings change.
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 2,
          signers:   [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: payer.address, permission: permissions::ALL)
          ]
        )

        # Atomically lower the threshold and remove the second signer —
        # ordered so the threshold invariant holds after each action.
        @tx = program.execute_settings_transaction_sync(
          payer:      creator,
          settings:   @identity.settings_address,
          signers:    [creator, payer],
          rent_payer: creator,
          actions:    [
            action_klass.change_threshold(1),
            action_klass.remove_signer(payer)
          ]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @settings = program.get_settings(settings_address: @identity.settings_address)
      end

      it 'lowers the threshold' do
        assert_equal 1, @settings.threshold
      end

      it 'removes the signer' do
        assert_equal 1, @settings.signers.length
        assert_equal creator.address, @settings.signers.first.pubkey
      end
    end

    describe 'when the smart account is controlled' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )
      end

      it 'rejects the transaction with NotSupportedForControlled' do
        error = assert_raises(Solace::Errors::RPCError) do
          program.execute_settings_transaction_sync(
            payer:      creator,
            settings:   @identity.settings_address,
            signers:    [creator],
            rent_payer: creator,
            actions:    [action_klass.set_time_lock(120)]
          )
        end

        # NotSupportedForControlled — error code 6021 (0x1785)
        assert_match(/0x1785/, error.message)
      end
    end

    describe 'when consensus is not reached' do
      before(:all) do
        @second_signer = Solace::Keypair.generate

        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 2,
          signers:   [
            signer_klass.new(pubkey: creator.address, permission: permissions::ALL),
            signer_klass.new(pubkey: @second_signer.address, permission: permissions::ALL)
          ]
        )
      end

      it 'rejects a single co-signer on a threshold-2 account' do
        error = assert_raises(Solace::Errors::RPCError) do
          program.execute_settings_transaction_sync(
            payer:      creator,
            settings:   @identity.settings_address,
            signers:    [creator],
            rent_payer: creator,
            actions:    [action_klass.set_time_lock(120)]
          )
        end

        assert_kind_of Solace::Errors::RPCError, error
      end
    end

    describe 'managing spending limits on an autonomous account' do
      let(:period) { Solace::SquadsSmartAccounts::Period }

      before(:all) do
        # Autonomous 1-of-1 account with a funded default vault.
        @identity = create_smart_account(
          program,
          payer:     creator,
          creator:,
          threshold: 1,
          signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        fund_account(connection, @identity.smart_account_address, 1_000_000_000)

        @seed     = Solace::Keypair.generate
        @delegate = Solace::Keypair.generate

        @spending_limit_address, = program.get_spending_limit_address(
          settings_address: @identity.settings_address,
          seed:             @seed
        )

        # 1. Grant the limit through consensus (AddSpendingLimit action).
        tx = program.execute_settings_transaction_sync(
          payer:                   creator,
          settings:                @identity.settings_address,
          signers:                 [creator],
          rent_payer:              creator,
          spending_limit_accounts: [@spending_limit_address],
          actions:                 [
            action_klass.add_spending_limit(
              seed:          @seed,
              account_index: 0,
              mint:          Solace::SquadsSmartAccounts::DEFAULT_PUBKEY,
              amount:        300_000_000,
              period:        period::DAY,
              signers:       [@delegate.address],
              destinations:  [],
              expiration:    Solace::SquadsSmartAccounts::I64_MAX
            )
          ]
        )
        connection.wait_for_confirmed_signature { tx.signature }

        @spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)

        # 2. The delegate spends within the limit (sponsored by creator).
        @recipient = Solace::Keypair.generate

        tx = program.use_spending_limit(
          payer:          creator,
          settings:       @identity.settings_address,
          signer:         @delegate,
          spending_limit: @spending_limit_address,
          smart_account:  @identity.smart_account_address,
          destination:    @recipient.address,
          amount:         100_000_000
        )
        connection.wait_for_confirmed_signature { tx.signature }

        # 3. Revoke the limit through consensus (RemoveSpendingLimit action).
        tx = program.execute_settings_transaction_sync(
          payer:                   creator,
          settings:                @identity.settings_address,
          signers:                 [creator],
          rent_payer:              creator,
          spending_limit_accounts: [@spending_limit_address],
          actions:                 [action_klass.remove_spending_limit(@spending_limit_address)]
        )
        connection.wait_for_confirmed_signature { tx.signature }
      end

      it 'creates the spending limit through consensus' do
        assert_equal 300_000_000, @spending_limit.amount
        assert_equal [@delegate.address], @spending_limit.signers
      end

      it 'lets the delegate spend within the limit' do
        assert_equal 100_000_000, connection.get_balance(@recipient.address)
      end

      it 'closes the spending limit through consensus' do
        assert_nil connection.get_account_info(@spending_limit_address)
      end
    end
  end

  describe '#add_spending_limit_as_authority' do
    let(:period) { Solace::SquadsSmartAccounts::Period }

    describe 'when the authority pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @seed = Solace::Keypair.generate

        @spending_limit_address, = program.get_spending_limit_address(
          settings_address: @identity.settings_address,
          seed:             @seed
        )

        @tx = program.add_spending_limit_as_authority(
          payer:              creator,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         creator,
          spending_limit:     @spending_limit_address,
          seed:               @seed,
          amount:             100_000_000,
          period:             period::WEEK,
          signers:            [creator.address]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'creates the spending limit' do
        assert_equal 100_000_000, @spending_limit.amount
        assert_equal period::WEEK, @spending_limit.period
        assert_equal [creator.address], @spending_limit.signers
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @seed = Solace::Keypair.generate

        @spending_limit_address, = program.get_spending_limit_address(
          settings_address: @identity.settings_address,
          seed:             @seed
        )

        @creator_starting_balance = connection.get_balance(creator.address)

        # The sponsor pays the fee and the new account's rent; the authority only signs.
        @tx = program.add_spending_limit_as_authority(
          payer:,
          settings:           @identity.settings_address,
          settings_authority: creator,
          rent_payer:         payer,
          spending_limit:     @spending_limit_address,
          seed:               @seed,
          amount:             100_000_000,
          period:             period::WEEK,
          signers:            [creator.address]
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'creates the spending limit' do
        assert_equal 100_000_000, @spending_limit.amount
      end

      it 'deducts nothing from the authority' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end
  end

  describe '#use_spending_limit' do
    let(:period) { Solace::SquadsSmartAccounts::Period }

    # Creates a controlled account with a SOL spending limit granted to a
    # non-member delegate key, funds the vault, and returns
    # [settings_address, vault_address, spending_limit_address].
    #
    # The delegate is deliberately NOT a member of the smart account: the
    # program only checks the limit's own signer list at use time, making
    # non-member delegation (hot keys, agents) the primary use case.
    def grant_funded_spending_limit(delegate)
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      spending_limit_address = grant_spending_limit(
        program,
        identity:,
        authority: creator,
        delegate:  delegate.address,
        amount:    500_000_000,
        period:    period::DAY
      )

      fund_account(connection, identity.smart_account_address, 1_000_000_000)

      [identity.settings_address, identity.smart_account_address, spending_limit_address]
    end

    describe 'when the delegate pays for the transaction' do
      before(:all) do
        # The payer fixture acts as a funded, non-member delegate.
        @settings_address, @vault_address, @spending_limit_address = grant_funded_spending_limit(payer)
        @recipient                                                 = Solace::Keypair.generate

        @tx = program.use_spending_limit(
          payer:,
          settings:       @settings_address,
          signer:         payer,
          spending_limit: @spending_limit_address,
          smart_account:  @vault_address,
          destination:    @recipient.address,
          amount:         150_000_000
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'transfers the amount and decrements the allowance' do
        assert_equal 150_000_000, connection.get_balance(@recipient.address)

        spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)
        assert_equal 350_000_000, spending_limit.remaining_amount
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        # A fresh, unfunded keypair as the delegate: it only signs — the
        # sponsor pays the fee, proving fully gasless delegated spending.
        @delegate = Solace::Keypair.generate

        @settings_address, @vault_address, @spending_limit_address = grant_funded_spending_limit(@delegate)
        @recipient                                                 = Solace::Keypair.generate

        @tx = program.use_spending_limit(
          payer:,
          settings:       @settings_address,
          signer:         @delegate,
          spending_limit: @spending_limit_address,
          smart_account:  @vault_address,
          destination:    @recipient.address,
          amount:         150_000_000
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'transfers the amount to the destination' do
        assert_equal 150_000_000, connection.get_balance(@recipient.address)
      end

      it 'lets an unfunded delegate spend without holding any SOL' do
        assert_equal 0, connection.get_balance(@delegate.address)
      end
    end

    describe 'spending an SPL Token limit' do
      let(:spl_token) { Solace::Programs::SplToken.new(connection:) }
      let(:mint) { fixtures.load_keypair('spl-mint') }
      let(:mint_authority) { fixtures.load_keypair('mint-authority') }

      before(:all) do
        @minted_amount   = 1_000_000
        @limit_amount    = 500_000
        @transfer_amount = 150_000

        # Controlled account; creator authority, payer is a non-member delegate.
        identity = create_smart_account(
          program,
          payer:              creator,
          creator:,
          threshold:          1,
          settings_authority: creator.address,
          signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
        )

        @spending_limit_address = grant_spending_limit(
          program,
          identity:,
          authority: creator,
          delegate:  payer.address,
          amount:    @limit_amount,
          period:    period::DAY,
          mint:      mint.address
        )

        # Fund the vault's ATA; create the destination owner's ATA.
        vault_ata = create_ata(
          connection,
          payer:            creator,
          owner:            identity.smart_account_address,
          mint:             mint.address,
          token_program_id: Solace::Constants::TOKEN_PROGRAM_ID
        )

        mint_tokens(
          spl_token,
          payer:       creator,
          mint:        mint.address,
          destination: vault_ata,
          amount:      @minted_amount,
          authority:   mint_authority
        )

        @recipient       = Solace::Keypair.generate
        @destination_ata = create_ata(
          connection,
          payer:            creator,
          owner:            @recipient.address,
          mint:             mint.address,
          token_program_id: Solace::Constants::TOKEN_PROGRAM_ID
        )

        @recipient_starting_balance = connection.get_token_account_balance(@destination_ata)['amount'].to_i

        # The non-member delegate (payer) both pays the fee and authorizes the spend.
        @tx = program.use_spending_limit(
          payer:,
          settings:       identity.settings_address,
          signer:         payer,
          spending_limit: @spending_limit_address,
          smart_account:  identity.smart_account_address,
          destination:    @recipient.address,
          amount:         @transfer_amount,
          decimals:       6,
          mint:           mint.address,
          token_program:  Solace::Constants::TOKEN_PROGRAM_ID
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @recipient_ending_balance = connection.get_token_account_balance(@destination_ata)['amount'].to_i
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'credits the transfer amount to the destination ATA' do
        assert_equal @recipient_starting_balance + @transfer_amount, @recipient_ending_balance
      end

      it 'decrements the remaining allowance by the transfer amount' do
        spending_limit = program.get_spending_limit(spending_limit_address: @spending_limit_address)
        assert_equal @limit_amount - @transfer_amount, spending_limit.remaining_amount
      end
    end
  end

  describe '#remove_spending_limit_as_authority' do
    let(:period) { Solace::SquadsSmartAccounts::Period }

    # Creates a controlled account with a spending limit and returns
    # [settings_address, spending_limit_address].
    def grant_removable_spending_limit
      identity = create_smart_account(
        program,
        payer:              creator,
        creator:,
        threshold:          1,
        settings_authority: creator.address,
        signers:            [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      spending_limit_address = grant_spending_limit(
        program,
        identity:,
        authority: creator,
        delegate:  Solace::Keypair.generate.address,
        amount:    100_000_000,
        period:    period::DAY
      )

      [identity.settings_address, spending_limit_address]
    end

    describe 'when the authority pays for the transaction' do
      before(:all) do
        @settings_address, @spending_limit_address = grant_removable_spending_limit

        @tx = program.remove_spending_limit_as_authority(
          payer:              creator,
          settings:           @settings_address,
          settings_authority: creator,
          spending_limit:     @spending_limit_address,
          rent_collector:     creator.address
        )

        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'closes the spending limit account' do
        assert_nil connection.get_account_info(@spending_limit_address)
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        @settings_address, @spending_limit_address = grant_removable_spending_limit

        @creator_starting_balance = connection.get_balance(creator.address)
        @spending_limit_rent      = connection.get_balance(@spending_limit_address)

        # The sponsor pays the fee; the rent refund still goes to the authority.
        @tx = program.remove_spending_limit_as_authority(
          payer:,
          settings:           @settings_address,
          settings_authority: creator,
          spending_limit:     @spending_limit_address,
          rent_collector:     creator.address
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @creator_ending_balance = connection.get_balance(creator.address)
      end

      it 'closes the spending limit account' do
        assert_nil connection.get_account_info(@spending_limit_address)
      end

      it 'credits the rent refund to the rent collector' do
        assert_equal @creator_starting_balance + @spending_limit_rent, @creator_ending_balance
      end
    end
  end

  describe '#create_transaction' do
    # Creates an autonomous 1-of-1 smart account (paid by the creator) and funds
    # its default vault. Returned identity is the subject of a later createTransaction.
    def funded_account
      identity = create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      fund_account(connection, identity.smart_account_address, 1_000_000_000)
      identity
    end

    # Stores a vault → recipient transfer transaction and returns
    # [tx, deserialized Transaction].
    def store_vault_transfer(identity:, payer:, rent_payer:)
      tx = program.create_transaction(
        payer:,
        settings:     identity.settings_address,
        creator:,
        rent_payer:,
        instructions: [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     identity.smart_account_address,
            to:       Solace::Keypair.generate.address,
            lamports: 250_000_000
          )
        ]
      )

      connection.wait_for_confirmed_signature { tx.signature }

      transaction_address, = program.get_transaction_address(
        settings_address:  identity.settings_address,
        transaction_index: 1
      )

      [tx, program.get_transaction(transaction_address:)]
    end

    describe 'when the creator pays for the transaction' do
      before(:all) do
        @tx, @transaction = store_vault_transfer(identity: funded_account, payer: creator, rent_payer: creator)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'stores the transaction at index 1 for the default vault' do
        assert_equal 1, @transaction.index
        assert_equal 0, @transaction.account_index
      end

      it 'compiles the inner vault-transfer message' do
        assert_equal 1, @transaction.num_signers
        assert_equal 3, @transaction.account_keys.length
      end
    end

    describe 'when a separate sponsor pays for the transaction' do
      before(:all) do
        identity = funded_account

        # Snapshot after setup so the delta reflects only the createTransaction.
        @creator_starting_balance = connection.get_balance(creator.address)
        @tx, @transaction         = store_vault_transfer(identity:, payer:, rent_payer: payer)
        @creator_ending_balance   = connection.get_balance(creator.address)
      end

      it 'stores the transaction' do
        assert_equal 1, @transaction.index
      end

      it 'deducts nothing from the creator (sponsor pays the fee and account rent)' do
        assert_equal @creator_starting_balance, @creator_ending_balance
      end
    end
  end

  # The async transaction lifecycle: createProposal → (activate) → vote →
  # executeTransaction. Each phase builds on a freshly funded 1-of-1 autonomous
  # account whose first stored transaction (index 1) is a vault → recipient
  # transfer.
  describe 'async transaction lifecycle' do
    let(:vault_funding)   { 1_000_000_000 }
    let(:transfer_amount) { 250_000_000 }

    # Creates a funded autonomous 1-of-1 account (creator pays and owns it).
    def lifecycle_account
      identity = create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )

      fund_account(connection, identity.smart_account_address, vault_funding)
      identity
    end

    # Stores a vault → recipient transfer as transaction index 1 and waits.
    def store_transfer(identity:, recipient:)
      tx = program.create_transaction(
        payer:        creator,
        settings:     identity.settings_address,
        creator:,
        rent_payer:   creator,
        instructions: [
          Solace::Composers::SystemProgramTransferComposer.new(
            from:     identity.smart_account_address,
            to:       recipient.address,
            lamports: transfer_amount
          )
        ]
      )

      connection.wait_for_confirmed_signature { tx.signature }
    end

    # Opens a proposal for transaction index 1 and waits.
    def open_proposal(identity:, draft: false)
      tx = program.create_proposal(
        payer:             creator,
        settings:          identity.settings_address,
        creator:,
        rent_payer:        creator,
        transaction_index: 1,
        draft:
      )

      connection.wait_for_confirmed_signature { tx.signature }
    end

    # Fetches the current status of the index-1 proposal.
    def proposal_status(identity:)
      proposal_address, = program.get_proposal_address(
        settings_address:  identity.settings_address,
        transaction_index: 1
      )

      program.get_proposal(proposal_address:).status
    end

    describe '#create_proposal' do
      before(:all) do
        @identity  = lifecycle_account
        @recipient = Solace::Keypair.generate
        store_transfer(identity: @identity, recipient: @recipient)

        @tx = program.create_proposal(
          payer:             creator,
          settings:          @identity.settings_address,
          creator:,
          rent_payer:        creator,
          transaction_index: 1
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @status = proposal_status(identity: @identity)
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'opens the proposal in the active state' do
        assert_equal :active, @status
      end
    end

    describe '#activate_proposal' do
      before(:all) do
        @identity  = lifecycle_account
        @recipient = Solace::Keypair.generate
        store_transfer(identity: @identity, recipient: @recipient)
        open_proposal(identity: @identity, draft: true)

        @draft_status = proposal_status(identity: @identity)

        @tx = program.activate_proposal(
          payer:             creator,
          settings:          @identity.settings_address,
          signer:            creator,
          transaction_index: 1
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @active_status = proposal_status(identity: @identity)
      end

      it 'starts the proposal as a draft' do
        assert_equal :draft, @draft_status
      end

      it 'transitions the proposal to active' do
        assert_equal :active, @active_status
      end
    end

    describe '#approve_proposal' do
      before(:all) do
        @identity  = lifecycle_account
        @recipient = Solace::Keypair.generate
        store_transfer(identity: @identity, recipient: @recipient)
        open_proposal(identity: @identity)

        @tx = program.approve_proposal(
          payer:             creator,
          settings:          @identity.settings_address,
          signer:            creator,
          transaction_index: 1
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @status = proposal_status(identity: @identity)
      end

      it 'marks the proposal approved once approvals reach the threshold' do
        assert_equal :approved, @status
      end
    end

    describe '#reject_proposal' do
      before(:all) do
        @identity  = lifecycle_account
        @recipient = Solace::Keypair.generate
        store_transfer(identity: @identity, recipient: @recipient)
        open_proposal(identity: @identity)

        @tx = program.reject_proposal(
          payer:             creator,
          settings:          @identity.settings_address,
          signer:            creator,
          transaction_index: 1
        )

        connection.wait_for_confirmed_signature { @tx.signature }

        @status = proposal_status(identity: @identity)
      end

      it 'marks the proposal rejected once rejections reach the cutoff' do
        assert_equal :rejected, @status
      end

      it 'refuses to execute a rejected proposal' do
        assert_raises(Solace::Errors::RPCError) do
          program.execute_transaction(
            payer:             creator,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
        end
      end
    end

    describe '#cancel_proposal' do
      # Advances a fresh account's index-1 proposal to Approved (the only state
      # from which it can be cancelled) and returns the identity.
      def approved_account
        identity   = lifecycle_account
        @recipient = Solace::Keypair.generate
        store_transfer(identity:, recipient: @recipient)
        open_proposal(identity:)

        approve_tx = program.approve_proposal(
          payer:             creator,
          settings:          identity.settings_address,
          signer:            creator,
          transaction_index: 1
        )
        connection.wait_for_confirmed_signature { approve_tx.signature }

        identity
      end

      describe 'when the signer pays for the transaction' do
        before(:all) do
          @identity = approved_account

          @tx = program.cancel_proposal(
            payer:             creator,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
          connection.wait_for_confirmed_signature { @tx.signature }

          @status = proposal_status(identity: @identity)
        end

        it 'returns the signed transaction' do
          assert_kind_of Solace::Transaction, @tx
        end

        it 'marks the proposal cancelled once cancellations reach the threshold' do
          assert_equal :cancelled, @status
        end

        it 'refuses to execute a cancelled proposal' do
          assert_raises(Solace::Errors::RPCError) do
            program.execute_transaction(
              payer:             creator,
              settings:          @identity.settings_address,
              signer:            creator,
              transaction_index: 1
            )
          end
        end
      end

      describe 'when a separate sponsor pays for the transaction' do
        before(:all) do
          @identity = approved_account

          @payer_starting_balance   = connection.get_balance(payer.address)
          @creator_starting_balance = connection.get_balance(creator.address)

          # The sponsor pays the fee; the creator only signs for Vote consensus.
          @tx = program.cancel_proposal(
            payer:,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
          connection.wait_for_confirmed_signature { @tx.signature }

          @payer_ending_balance   = connection.get_balance(payer.address)
          @creator_ending_balance = connection.get_balance(creator.address)

          @status = proposal_status(identity: @identity)
        end

        it 'marks the proposal cancelled' do
          assert_equal :cancelled, @status
        end

        it 'deducts only the transaction fee from the sponsor' do
          # 2 signatures (payer + creator) at 5000 lamports per signature
          assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
        end

        it 'deducts nothing from the voting signer' do
          assert_equal @creator_starting_balance, @creator_ending_balance
        end
      end
    end

    describe '#execute_transaction' do
      describe 'when the signer pays for the transaction' do
        before(:all) do
          @identity  = lifecycle_account
          @recipient = Solace::Keypair.generate
          store_transfer(identity: @identity, recipient: @recipient)
          open_proposal(identity: @identity)

          approve_tx = program.approve_proposal(
            payer:             creator,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
          connection.wait_for_confirmed_signature { approve_tx.signature }

          @tx = program.execute_transaction(
            payer:             creator,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
          connection.wait_for_confirmed_signature { @tx.signature }

          @status = proposal_status(identity: @identity)
        end

        it 'returns the signed transaction' do
          assert_kind_of Solace::Transaction, @tx
        end

        it 'transfers the amount out of the vault to the recipient' do
          assert_equal transfer_amount, connection.get_balance(@recipient.address)
          assert_equal vault_funding - transfer_amount,
                       connection.get_balance(@identity.smart_account_address)
        end

        it 'marks the proposal executed' do
          assert_equal :executed, @status
        end
      end

      describe 'when a separate sponsor pays for the transaction' do
        before(:all) do
          @identity  = lifecycle_account
          @recipient = Solace::Keypair.generate
          store_transfer(identity: @identity, recipient: @recipient)
          open_proposal(identity: @identity)

          approve_tx = program.approve_proposal(
            payer:             creator,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
          connection.wait_for_confirmed_signature { approve_tx.signature }

          @payer_starting_balance   = connection.get_balance(payer.address)
          @creator_starting_balance = connection.get_balance(creator.address)

          # The sponsor pays the fee; the creator only signs for Execute consensus.
          @tx = program.execute_transaction(
            payer:,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1
          )
          connection.wait_for_confirmed_signature { @tx.signature }

          @payer_ending_balance   = connection.get_balance(payer.address)
          @creator_ending_balance = connection.get_balance(creator.address)
        end

        it 'transfers the amount out of the vault to the recipient' do
          assert_equal transfer_amount, connection.get_balance(@recipient.address)
          assert_equal vault_funding - transfer_amount,
                       connection.get_balance(@identity.smart_account_address)
        end

        it 'deducts only the transaction fee from the sponsor' do
          # 2 signatures (payer + creator) at 5000 lamports per signature
          assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
        end

        it 'deducts nothing from the executing signer' do
          assert_equal @creator_starting_balance, @creator_ending_balance
        end
      end
    end
  end

  # The settings-transaction async lifecycle: createSettingsTransaction →
  # createProposal → approveProposal → executeSettingsTransaction →
  # closeSettingsTransaction, applied to an autonomous account whose first stored
  # transaction (index 1) carries a SetTimeLock action.
  describe 'settings transaction lifecycle' do
    let(:new_time_lock) { 100 }

    # Creates an autonomous 1-of-1 account (creator pays and owns it).
    def autonomous_account
      create_smart_account(
        program,
        payer:     creator,
        creator:,
        threshold: 1,
        signers:   [signer_klass.new(pubkey: creator.address, permission: permissions::ALL)]
      )
    end

    # Stores a SetTimeLock settings transaction (index 1) and waits.
    def store_time_lock_change(identity:, payer:, rent_payer:)
      tx = program.create_settings_transaction(
        payer:,
        settings:   identity.settings_address,
        creator:,
        rent_payer:,
        actions:    [Solace::SquadsSmartAccounts::SettingsAction.set_time_lock(new_time_lock)]
      )

      connection.wait_for_confirmed_signature { tx.signature }
    end

    # Opens and approves the index-1 proposal (creator pays and votes) and waits.
    def propose_and_approve(identity:)
      propose_tx = program.create_proposal(
        payer:             creator,
        settings:          identity.settings_address,
        creator:,
        rent_payer:        creator,
        transaction_index: 1
      )
      connection.wait_for_confirmed_signature { propose_tx.signature }

      approve_tx = program.approve_proposal(
        payer:             creator,
        settings:          identity.settings_address,
        signer:            creator,
        transaction_index: 1
      )
      connection.wait_for_confirmed_signature { approve_tx.signature }
    end

    describe '#create_settings_transaction' do
      describe 'when the creator pays for the transaction' do
        before(:all) do
          @identity = autonomous_account
          store_time_lock_change(identity: @identity, payer: creator, rent_payer: creator)

          @transaction_address, = program.get_transaction_address(
            settings_address:  @identity.settings_address,
            transaction_index: 1
          )
          @transaction          = program.get_settings_transaction(transaction_address: @transaction_address)
        end

        it 'stores the settings transaction at index 1' do
          assert_equal 1, @transaction.index
        end

        it 'records the creator' do
          assert_equal creator.address, @transaction.creator
        end
      end

      describe 'when a separate sponsor pays for the transaction' do
        before(:all) do
          @identity = autonomous_account

          @creator_starting_balance = connection.get_balance(creator.address)
          store_time_lock_change(identity: @identity, payer:, rent_payer: payer)
          @creator_ending_balance   = connection.get_balance(creator.address)
        end

        it 'deducts nothing from the creator (sponsor pays the fee and account rent)' do
          assert_equal @creator_starting_balance, @creator_ending_balance
        end
      end
    end

    describe '#execute_settings_transaction' do
      describe 'when the signer pays for the transaction' do
        before(:all) do
          @identity = autonomous_account
          store_time_lock_change(identity: @identity, payer: creator, rent_payer: creator)
          propose_and_approve(identity: @identity)

          @tx = program.execute_settings_transaction(
            payer:             creator,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1,
            rent_payer:        creator
          )
          connection.wait_for_confirmed_signature { @tx.signature }

          @settings = program.get_settings(settings_address: @identity.settings_address)
        end

        it 'returns the signed transaction' do
          assert_kind_of Solace::Transaction, @tx
        end

        it 'applies the SetTimeLock action to the settings' do
          assert_equal new_time_lock, @settings.time_lock
        end
      end

      describe 'when a separate sponsor pays for the transaction' do
        before(:all) do
          @identity = autonomous_account
          store_time_lock_change(identity: @identity, payer: creator, rent_payer: creator)
          propose_and_approve(identity: @identity)

          @payer_starting_balance   = connection.get_balance(payer.address)
          @creator_starting_balance = connection.get_balance(creator.address)

          # The sponsor pays the fee and rent; the creator only signs for consensus.
          @tx = program.execute_settings_transaction(
            payer:,
            settings:          @identity.settings_address,
            signer:            creator,
            transaction_index: 1,
            rent_payer:        payer
          )
          connection.wait_for_confirmed_signature { @tx.signature }

          @payer_ending_balance   = connection.get_balance(payer.address)
          @creator_ending_balance = connection.get_balance(creator.address)
          @settings               = program.get_settings(settings_address: @identity.settings_address)
        end

        it 'applies the SetTimeLock action to the settings' do
          assert_equal new_time_lock, @settings.time_lock
        end

        it 'deducts only the transaction fee from the sponsor (no realloc for SetTimeLock)' do
          # 2 signatures (payer + creator) at 5000 lamports per signature
          assert_equal @payer_starting_balance - (2 * 5000), @payer_ending_balance
        end

        it 'deducts nothing from the executing signer' do
          assert_equal @creator_starting_balance, @creator_ending_balance
        end
      end
    end

    describe '#close_settings_transaction' do
      before(:all) do
        @identity = autonomous_account
        store_time_lock_change(identity: @identity, payer: creator, rent_payer: creator)
        propose_and_approve(identity: @identity)

        execute_tx = program.execute_settings_transaction(
          payer:             creator,
          settings:          @identity.settings_address,
          signer:            creator,
          transaction_index: 1,
          rent_payer:        creator
        )
        connection.wait_for_confirmed_signature { execute_tx.signature }

        @proposal_address,    = program.get_proposal_address(
          settings_address:  @identity.settings_address,
          transaction_index: 1
        )
        @transaction_address, = program.get_transaction_address(
          settings_address:  @identity.settings_address,
          transaction_index: 1
        )

        # Rent collectors default to the on-chain stored collectors (the creator).
        @tx = program.close_settings_transaction(
          payer:             creator,
          settings:          @identity.settings_address,
          transaction_index: 1
        )
        connection.wait_for_confirmed_signature { @tx.signature }
      end

      it 'returns the signed transaction' do
        assert_kind_of Solace::Transaction, @tx
      end

      it 'closes the settings transaction account' do
        assert_nil connection.get_account_info(@transaction_address)
      end

      it 'closes the proposal account' do
        assert_nil connection.get_account_info(@proposal_address)
      end
    end
  end
end
