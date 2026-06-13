# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::CreateTransactionInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::CreateTransactionInstruction }

  describe '.build' do
    let(:message_bytes) { [1, 1, 1, 0, 0, 0] }

    let(:ix) do
      klass.build(
        account_index:        0,
        ephemeral_signers:    0,
        transaction_message:  message_bytes,
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

    it 'data begins with the create_transaction discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data leads with the TransactionPayload enum variant byte' do
      assert_equal 0, ix.data[8]
    end

    it 'data encodes account_index and ephemeral_signers after the variant byte' do
      assert_equal [0, 0], ix.data[9, 2]
    end

    it 'data encodes the message as a Borsh bytes field (u32 length + bytes)' do
      assert_equal Solace::Utils::Codecs.encode_le_u32(message_bytes.length).bytes, ix.data[11, 4]
      assert_equal message_bytes, ix.data[15, message_bytes.length]
    end

    it 'data encodes a nil memo as a single trailing zero byte' do
      assert_equal 0, ix.data.last
    end
  end
end
