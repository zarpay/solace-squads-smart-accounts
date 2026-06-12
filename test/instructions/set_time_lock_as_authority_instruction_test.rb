# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::SetTimeLockAsAuthorityInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::SetTimeLockAsAuthorityInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        time_lock:                3600,
        memo:                     nil,
        settings_index:           0,
        settings_authority_index: 1,
        rent_payer_index:         2,
        system_program_index:     3,
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

    it 'data begins with the set_time_lock_as_authority discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes the time lock as a little-endian u32' do
      assert_equal [3600].pack('L<').bytes, ix.data[8, 4]
    end

    it 'data encodes a nil memo as a single zero byte' do
      assert_equal [0], ix.data[12..]
    end
  end
end
