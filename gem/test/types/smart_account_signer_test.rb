# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::SmartAccountSigner do
  let(:klass) { Solace::SquadsSmartAccounts::SmartAccountSigner }
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }
  let(:keypair) { Solace::Keypair.generate }

  it 'accepts a base58 string pubkey' do
    signer = klass.new(pubkey: keypair.address, permission: permissions::ALL)

    assert_equal keypair.address, signer.pubkey
  end

  it 'normalizes a Keypair to its base58 address' do
    signer = klass.new(pubkey: keypair, permission: permissions::ALL)

    assert_equal keypair.address, signer.pubkey
  end

  it 'normalizes a PublicKey to its base58 address' do
    public_key = Solace::PublicKey.new(keypair.public_key_bytes)

    signer = klass.new(pubkey: public_key, permission: permissions::ALL)

    assert_equal keypair.address, signer.pubkey
  end

  it 'exposes the permission bitmask' do
    signer = klass.new(pubkey: keypair, permission: permissions::VOTE)

    assert_equal permissions::VOTE, signer.permission
  end
end
