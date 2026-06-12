# frozen_string_literal: true

require_relative '../test_helper'

include Solace::SquadsSmartAccounts

describe Instructions::AddSignerAsAuthorityInstruction do
  describe '.build' do
    let(:new_signer_pubkey) { 'GqH8rytYU4AtEePST5x1JvgDTYZtVGoSbZ5zRZU2vPDh' }

    let(:new_signer) do
      SmartAccountSigner.new(pubkey: new_signer_pubkey, permission: Permissions::ALL)
    end

    let(:ix) do
      Instructions::AddSignerAsAuthorityInstruction.build(
        new_signer:               new_signer,
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

    it 'data begins with the add_signer_as_authority discriminator' do
      assert_equal Instructions::AddSignerAsAuthorityInstruction::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes the new signer as pubkey + permission mask' do
      assert_equal Solace::Utils::Codecs.base58_to_bytes(new_signer_pubkey), ix.data[8, 32]
      assert_equal Permissions::ALL, ix.data[40]
    end

    it 'data encodes a nil memo as a single zero byte' do
      assert_equal [0], ix.data[41..]
    end
  end
end
