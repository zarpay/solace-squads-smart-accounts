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
end
