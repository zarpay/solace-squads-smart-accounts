# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::CreateProposalInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::CreateProposalInstruction }

  describe '.build' do
    let(:ix) do
      klass.build(
        transaction_index:    7,
        draft:                false,
        settings_index:       0,
        proposal_index:       1,
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

    it 'data begins with the create_proposal discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes the transaction index as a little-endian u64' do
      assert_equal Solace::Utils::Codecs.encode_le_u64(7).bytes, ix.data[8, 8]
    end

    it 'data encodes draft false as a trailing 0 byte' do
      assert_equal 0, ix.data.last
    end

    it 'data encodes draft true as a trailing 1 byte' do
      draft_ix = klass.build(
        transaction_index:    7,
        draft:                true,
        settings_index:       0,
        proposal_index:       1,
        creator_index:        2,
        rent_payer_index:     3,
        system_program_index: 4,
        program_index:        5
      )

      assert_equal 1, draft_ix.data.last
    end
  end
end
