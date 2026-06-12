# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::RemoveSpendingLimitAsAuthorityInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::RemoveSpendingLimitAsAuthorityInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        memo:                     nil,
        settings_index:           0,
        settings_authority_index: 1,
        spending_limit_index:     2,
        rent_collector_index:     3,
        program_index:            4
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 4, ix.program_index
    end

    it 'orders accounts per the IDL' do
      assert_equal [0, 1, 2, 3, 4], ix.accounts
    end

    it 'data begins with the remove_spending_limit_as_authority discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes a nil memo as a single zero byte' do
      assert_equal [0], ix.data[8..]
    end
  end
end
