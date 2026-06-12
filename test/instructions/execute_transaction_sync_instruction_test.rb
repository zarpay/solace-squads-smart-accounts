# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::ExecuteTransactionSyncInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::ExecuteTransactionSyncInstruction }

  describe '.build' do
    # One inner instruction, pre-compiled: indexes are relative to the full
    # remaining-accounts list (signers first, then inner accounts).
    let(:inner_instruction) do
      Solace::Instruction.new.tap do |ix|
        ix.program_index = 3          # remaining[3] is the inner program
        ix.accounts      = [1, 2]     # remaining[1] (vault) and remaining[2] (recipient)
        ix.data          = [2, 0, 0, 0, 64, 66, 15, 0, 0, 0, 0, 0] # transfer 1_000_000
      end
    end

    let(:ix) do
      klass.build(
        account_index:             0,
        num_signers:               1,
        instructions:              [inner_instruction],
        settings_index:            0,
        program_index:             1,
        signer_indices:            [2],
        remaining_account_indices: [3, 4, 5]
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 1, ix.program_index
    end

    it 'orders accounts as settings, program, signers, then remaining accounts' do
      assert_equal [0, 1, 2, 3, 4, 5], ix.accounts
    end

    it 'data begins with the execute_transaction_sync discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes account_index and num_signers as single bytes' do
      assert_equal [0, 1], ix.data[8, 2]
    end

    it 'data encodes the instructions as Borsh bytes wrapping a SmallVec' do
      small_vec = Solace::Utils::Codecs.encode_compiled_instructions([inner_instruction])

      # u32 LE byte-length prefix followed by the SmallVec content.
      assert_equal Solace::Utils::Codecs.encode_le_u32(small_vec.length).bytes, ix.data[10, 4]
      assert_equal small_vec, ix.data[14..]
    end
  end
end
