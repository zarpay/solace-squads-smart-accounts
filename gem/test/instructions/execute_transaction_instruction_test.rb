# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::ExecuteTransactionInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::ExecuteTransactionInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        settings_index:            0,
        proposal_index:            1,
        transaction_index:         2,
        signer_index:              3,
        program_index:             4,
        remaining_account_indices: [5, 6, 7]
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index to the Squads program' do
      assert_equal 4, ix.program_index
    end

    it 'orders the fixed accounts followed by the remaining accounts in order' do
      assert_equal [0, 1, 2, 3, 4, 5, 6, 7], ix.accounts
    end

    it 'data is the discriminator only (no args)' do
      assert_equal klass::DISCRIMINATOR, ix.data
    end
  end
end
