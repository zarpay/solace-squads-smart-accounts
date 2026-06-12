# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::Programs::SquadsSmartAccount do
  let(:klass) { Solace::Programs::SquadsSmartAccount }

  let(:fixtures) { Solace::SquadsSmartAccounts::Test::Fixtures }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:signer_klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }

  let(:connection) { Solace::Connection.new(commitment: 'processed') }
  let(:program) { klass.new(connection:) }
  let(:creator) { fixtures.load_keypair('creator') }

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
      let(:payer) { fixtures.load_keypair('payer') }

      before(:all) do
        @identity = program.next_smart_account
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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
      let(:payer) { fixtures.load_keypair('payer') }

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
end
