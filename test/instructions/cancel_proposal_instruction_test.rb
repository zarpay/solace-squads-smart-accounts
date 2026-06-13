# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::CancelProposalInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::CancelProposalInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        memo:                 nil,
        settings_index:       0,
        signer_index:         1,
        proposal_index:       2,
        system_program_index: 3,
        program_index:        4
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index to the Squads program' do
      assert_equal 4, ix.program_index
    end

    it 'orders accounts with a distinct systemProgram and trailing program' do
      assert_equal [0, 1, 2, 3, 4], ix.accounts
    end

    it 'data begins with the cancel_proposal discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes a nil memo as a single trailing zero byte' do
      assert_equal [0], ix.data[8..]
    end
  end
end
