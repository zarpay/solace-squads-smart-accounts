# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::CloseSettingsTransactionInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::CloseSettingsTransactionInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        settings_index:                   0,
        proposal_index:                   1,
        transaction_index:                2,
        proposal_rent_collector_index:    3,
        transaction_rent_collector_index: 4,
        system_program_index:             5,
        program_index:                    6
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index to the Squads program' do
      assert_equal 6, ix.program_index
    end

    it 'orders the seven accounts with the trailing program account' do
      assert_equal [0, 1, 2, 3, 4, 5, 6], ix.accounts
    end

    it 'data is the discriminator only (no args)' do
      assert_equal klass::DISCRIMINATOR, ix.data
    end
  end
end
