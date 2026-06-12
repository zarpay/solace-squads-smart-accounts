# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::SettingsAction do
  let(:klass) { Solace::SquadsSmartAccounts::SettingsAction }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:keypair) { Solace::Keypair.generate }

  describe '.add_signer' do
    let(:action) do
      klass.add_signer(pubkey: keypair, permission: permissions::ALL)
    end

    it 'uses variant 0' do
      assert_equal 0, action.variant
    end

    it 'encodes the variant index followed by pubkey and permission mask' do
      assert_equal [0] + Solace::Utils::Codecs.base58_to_bytes(keypair.address) + [permissions::ALL],
                   action.serialize
    end
  end

  describe '.remove_signer' do
    let(:action) { klass.remove_signer(keypair) }

    it 'uses variant 1' do
      assert_equal 1, action.variant
    end

    it 'encodes the variant index followed by the pubkey' do
      assert_equal [1] + Solace::Utils::Codecs.base58_to_bytes(keypair.address), action.serialize
    end

    it 'normalizes a Keypair to its base58 address' do
      assert_equal klass.remove_signer(keypair.address).serialize, action.serialize
    end
  end

  describe '.change_threshold' do
    let(:action) { klass.change_threshold(513) }

    it 'uses variant 2' do
      assert_equal 2, action.variant
    end

    it 'encodes the variant index followed by a little-endian u16' do
      assert_equal [2, 1, 2], action.serialize
    end
  end

  describe '.set_time_lock' do
    let(:action) { klass.set_time_lock(3600) }

    it 'uses variant 3' do
      assert_equal 3, action.variant
    end

    it 'encodes the variant index followed by a little-endian u32' do
      assert_equal [3] + [3600].pack('L<').bytes, action.serialize
    end
  end

  describe '.add_spending_limit' do
    let(:seed) { Solace::Keypair.generate }
    let(:allowed_signer) { Solace::Keypair.generate }

    let(:bytes) do
      klass.add_spending_limit(
        seed:,
        account_index: 7,
        mint:          Solace::SquadsSmartAccounts::DEFAULT_PUBKEY,
        amount:        500_000_000,
        period:        Solace::SquadsSmartAccounts::Period::DAY,
        signers:       [allowed_signer],
        destinations:  [],
        expiration:    Solace::SquadsSmartAccounts::I64_MAX
      ).serialize
    end

    it 'uses variant 4' do
      assert_equal 4, bytes[0]
    end

    it 'serializes the seed pubkey after the variant index' do
      assert_equal Solace::Utils::Codecs.base58_to_bytes(seed.address), bytes[1, 32]
    end

    it 'serializes the account index as a single byte' do
      assert_equal 7, bytes[33]
    end

    it 'serializes the SOL mint as 32 zero bytes' do
      assert_equal [0] * 32, bytes[34, 32]
    end

    it 'serializes the amount as a little-endian u64' do
      assert_equal [0, 101, 205, 29, 0, 0, 0, 0], bytes[66, 8]
    end

    it 'serializes the period as a single byte' do
      assert_equal Solace::SquadsSmartAccounts::Period::DAY, bytes[74]
    end

    it 'serializes the signers as a u32-prefixed vec of pubkeys' do
      assert_equal [1, 0, 0, 0], bytes[75, 4]
      assert_equal Solace::Utils::Codecs.base58_to_bytes(allowed_signer.address), bytes[79, 32]
    end

    it 'serializes empty destinations as a zero u32 count' do
      assert_equal [0, 0, 0, 0], bytes[111, 4]
    end

    it 'serializes a non-expiring expiration as i64::MAX' do
      assert_equal [255, 255, 255, 255, 255, 255, 255, 127], bytes[115, 8]
    end

    it 'has no trailing bytes' do
      assert_equal 123, bytes.length
    end
  end

  describe '.remove_spending_limit' do
    let(:spending_limit) { Solace::Keypair.generate }
    let(:action) { klass.remove_spending_limit(spending_limit) }

    it 'uses variant 5' do
      assert_equal 5, action.variant
    end

    it 'encodes the variant index followed by the spending limit pubkey' do
      assert_equal [5] + Solace::Utils::Codecs.base58_to_bytes(spending_limit.address), action.serialize
    end
  end
end
