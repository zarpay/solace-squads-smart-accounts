# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::ActivateProposalInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::ActivateProposalInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        settings_index: 0,
        signer_index:   1,
        proposal_index: 2,
        program_index:  3
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index to the Squads program' do
      assert_equal 3, ix.program_index
    end

    it 'orders the three accounts with no trailing program account' do
      assert_equal [0, 1, 2], ix.accounts
    end

    it 'data is the discriminator only (no args)' do
      assert_equal klass::DISCRIMINATOR, ix.data
    end
  end
end
