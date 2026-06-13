# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::ExecuteSettingsTransactionInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::ExecuteSettingsTransactionInstruction }

  describe '.build without spending limit accounts' do
    let(:ix) do
      klass.build(
        settings_index:       0,
        signer_index:         1,
        proposal_index:       2,
        transaction_index:    3,
        rent_payer_index:     4,
        system_program_index: 5,
        program_index:        6
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index to the Squads program' do
      assert_equal 6, ix.program_index
    end

    it 'orders the seven fixed accounts' do
      assert_equal [0, 1, 2, 3, 4, 5, 6], ix.accounts
    end

    it 'data is the discriminator only (no args)' do
      assert_equal klass::DISCRIMINATOR, ix.data
    end
  end

  describe '.build with spending limit accounts' do
    let(:ix) do
      klass.build(
        settings_index:         0,
        signer_index:           1,
        proposal_index:         2,
        transaction_index:      3,
        rent_payer_index:       4,
        system_program_index:   5,
        program_index:          6,
        spending_limit_indices: [7, 8]
      )
    end

    it 'appends the spending limit accounts after the fixed accounts' do
      assert_equal [0, 1, 2, 3, 4, 5, 6, 7, 8], ix.accounts
    end
  end
end
