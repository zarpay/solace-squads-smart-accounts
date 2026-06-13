# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::CreateSettingsTransactionInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::CreateSettingsTransactionInstruction }
  let(:actions) { [Solace::SquadsSmartAccounts::SettingsAction.change_threshold(2)] }

  describe '.build' do
    let(:ix) do
      klass.build(
        actions:,
        memo:                 nil,
        settings_index:       0,
        transaction_index:    1,
        creator_index:        2,
        rent_payer_index:     3,
        system_program_index: 4,
        program_index:        5
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index to the Squads program' do
      assert_equal 5, ix.program_index
    end

    it 'orders accounts per the IDL with the trailing program account' do
      assert_equal [0, 1, 2, 3, 4, 5], ix.accounts
    end

    it 'data begins with the create_settings_transaction discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes the actions vec after the discriminator' do
      assert_equal Solace::Utils::Codecs.encode_settings_actions(actions), ix.data[8...-1]
    end

    it 'data encodes a nil memo as a single trailing zero byte' do
      assert_equal 0, ix.data.last
    end
  end
end
