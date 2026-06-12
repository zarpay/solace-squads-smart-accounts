# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::AddSpendingLimitAsAuthorityInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::AddSpendingLimitAsAuthorityInstruction }

  describe '.build' do
    let(:seed) { Solace::Keypair.generate }
    let(:allowed_signer) { Solace::Keypair.generate }

    let(:ix) do
      klass.build(
        seed:,
        account_index:            0,
        mint:                     Solace::SquadsSmartAccounts::DEFAULT_PUBKEY,
        amount:                   500_000_000,
        period:                   Solace::SquadsSmartAccounts::Period::DAY,
        signers:                  [allowed_signer.address],
        destinations:             [],
        expiration:               Solace::SquadsSmartAccounts::I64_MAX,
        memo:                     nil,
        settings_index:           0,
        settings_authority_index: 1,
        spending_limit_index:     2,
        rent_payer_index:         3,
        system_program_index:     4,
        program_index:            5
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 5, ix.program_index
    end

    it 'orders accounts per the IDL' do
      assert_equal [0, 1, 2, 3, 4, 5], ix.accounts
    end

    it 'data begins with the add_spending_limit_as_authority discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data serializes the seed pubkey after the discriminator' do
      assert_equal Solace::Utils::Codecs.encode_pubkey(seed), ix.data[8, 32]
    end

    it 'data serializes account_index, mint, amount, and period at their offsets' do
      assert_equal 0, ix.data[40]
      assert_equal [0] * 32, ix.data[41, 32]
      assert_equal [0, 101, 205, 29, 0, 0, 0, 0], ix.data[73, 8]
      assert_equal Solace::SquadsSmartAccounts::Period::DAY, ix.data[81]
    end

    it 'data serializes the signer and destination vecs' do
      assert_equal [1, 0, 0, 0], ix.data[82, 4]
      assert_equal Solace::Utils::Codecs.encode_pubkey(allowed_signer), ix.data[86, 32]
      assert_equal [0, 0, 0, 0], ix.data[118, 4]
    end

    it 'data serializes the expiration and nil memo at the tail' do
      assert_equal [255, 255, 255, 255, 255, 255, 255, 127], ix.data[122, 8]
      assert_equal [0], ix.data[130..]
    end
  end
end
