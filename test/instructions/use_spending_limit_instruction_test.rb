# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::UseSpendingLimitInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::UseSpendingLimitInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        amount:                            200_000_000,
        decimals:                          9,
        memo:                              nil,
        settings_index:                    0,
        signer_index:                      1,
        spending_limit_index:              2,
        smart_account_index:               3,
        destination_index:                 4,
        system_program_index:              5,
        mint_index:                        6,
        smart_account_token_account_index: 6,
        destination_token_account_index:   6,
        token_program_index:               6,
        program_index:                     6
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 6, ix.program_index
    end

    it 'orders all eleven accounts per the IDL' do
      assert_equal [0, 1, 2, 3, 4, 5, 6, 6, 6, 6, 6], ix.accounts
    end

    it 'data begins with the use_spending_limit discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data serializes the amount as a little-endian u64' do
      assert_equal [0, 194, 235, 11, 0, 0, 0, 0], ix.data[8, 8]
    end

    it 'data serializes the decimals as a single byte' do
      assert_equal 9, ix.data[16]
    end

    it 'data serializes a nil memo as a single trailing zero byte' do
      assert_equal [0], ix.data[17..]
    end
  end
end
