# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::SettingsTransaction do
  let(:klass) { Solace::SquadsSmartAccounts::SettingsTransaction }
  let(:codecs) { Solace::Utils::Codecs }

  let(:settings) { Solace::Keypair.generate.address }
  let(:creator) { Solace::Keypair.generate.address }
  let(:rent_collector) { Solace::Keypair.generate.address }

  # Raw Borsh account bytes for a SettingsTransaction with an empty actions vec.
  let(:bytes) do
    [0, 0, 0, 0, 0, 0, 0, 0] + # 8-byte discriminator
      codecs.encode_pubkey(settings) +
      codecs.encode_pubkey(creator) +
      codecs.encode_pubkey(rent_collector) +
      codecs.encode_le_u64(4).bytes +
      [253] +                       # bump
      codecs.encode_le_u32(0).bytes # empty actions vec (ignored)
  end

  let(:transaction) { klass.deserialize(StringIO.new(bytes.pack('C*'))) }

  it 'decodes the settings account' do
    assert_equal settings, transaction.settings
  end

  it 'decodes the creator' do
    assert_equal creator, transaction.creator
  end

  it 'decodes the rent collector' do
    assert_equal rent_collector, transaction.rent_collector
  end

  it 'decodes the transaction index' do
    assert_equal 4, transaction.index
  end

  it 'decodes the bump' do
    assert_equal 253, transaction.bump
  end
end
