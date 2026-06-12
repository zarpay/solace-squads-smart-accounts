# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::SetNewSettingsAuthorityAsAuthorityInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::SetNewSettingsAuthorityAsAuthorityInstruction }

  describe '.build' do
    let(:new_settings_authority) { 'GqH8rytYU4AtEePST5x1JvgDTYZtVGoSbZ5zRZU2vPDh' }

    let(:ix) do
      klass.build(
        new_settings_authority:,
        memo:                     nil,
        settings_index:           0,
        settings_authority_index: 1,
        rent_payer_index:         2,
        system_program_index:     3,
        program_index:            4
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 4, ix.program_index
    end

    it 'orders accounts per the IDL' do
      assert_equal [0, 1, 2, 3, 4], ix.accounts
    end

    it 'data begins with the set_new_settings_authority_as_authority discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes the new settings authority pubkey' do
      assert_equal Solace::Utils::Codecs.base58_to_bytes(new_settings_authority), ix.data[8, 32]
    end

    it 'data encodes a nil memo as a single zero byte' do
      assert_equal [0], ix.data[40..]
    end
  end
end
