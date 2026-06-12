# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::ExecuteSettingsTransactionSyncInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::ExecuteSettingsTransactionSyncInstruction }
  let(:action_klass) { Solace::SquadsSmartAccounts::SettingsAction }

  describe '.build' do
    let(:actions) { [action_klass.change_threshold(2)] }

    let(:ix) do
      klass.build(
        num_signers:          1,
        actions:,
        memo:                 nil,
        settings_index:       0,
        rent_payer_index:     1,
        system_program_index: 2,
        program_index:        3,
        signer_indices:       [4]
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 3, ix.program_index
    end

    it 'orders accounts as settings, rent payer, system program, program, then signers' do
      assert_equal [0, 1, 2, 3, 4], ix.accounts
    end

    it 'data begins with the execute_settings_transaction_sync discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes num_signers as a single byte' do
      assert_equal 1, ix.data[8]
    end

    it 'data encodes the actions as a Borsh vec' do
      expected = Solace::Utils::Codecs.encode_settings_actions(actions)

      assert_equal expected, ix.data[9, expected.length]
    end

    it 'data encodes a nil memo as a single trailing zero byte' do
      assert_equal 0, ix.data.last
    end
  end
end
