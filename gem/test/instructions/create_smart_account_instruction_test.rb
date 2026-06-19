# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Instructions::CreateSmartAccountInstruction do
  let(:klass) { Solace::SquadsSmartAccounts::Instructions::CreateSmartAccountInstruction }

  describe '.build' do
    let(:creator_pubkey)  { 'GqH8rytYU4AtEePST5x1JvgDTYZtVGoSbZ5zRZU2vPDh' }
    let(:treasury_pubkey) { '4EKP9SRfykFkuBqJFBiBBTrSBMqxRGnmSQiNpFdJfJXq' }

    let(:signers) do
      [
        Solace::SquadsSmartAccounts::SmartAccountSigner.new(
          pubkey:     creator_pubkey,
          permission: Solace::SquadsSmartAccounts::Permissions::ALL
        )
      ]
    end

    let(:ix) do
      klass.build(
        settings_authority:   nil,
        threshold:            1,
        signers:,
        time_lock:            0,
        rent_collector:       nil,
        memo:                 nil,
        program_config_index: 0,
        treasury_index:       1,
        creator_index:        2,
        system_program_index: 3,
        program_index:        4,
        settings_index:       5
      )
    end

    it 'returns a Solace::Instruction' do
      assert_kind_of Solace::Instruction, ix
    end

    it 'sets the program index' do
      assert_equal 4, ix.program_index
    end

    it 'has accounts in IDL order with settings as remaining account' do
      assert_equal [0, 1, 2, 3, 4, 5], ix.accounts
    end

    it 'appends every candidate when settings_index is an array (windowed)' do
      windowed = klass.build(
        settings_authority:   nil,
        threshold:            1,
        signers:,
        time_lock:            0,
        rent_collector:       nil,
        memo:                 nil,
        program_config_index: 0,
        treasury_index:       1,
        creator_index:        2,
        system_program_index: 3,
        program_index:        4,
        settings_index:       [5, 6, 7]
      )

      assert_equal [0, 1, 2, 3, 4, 5, 6, 7], windowed.accounts
    end

    it 'data begins with the correct Anchor discriminator' do
      assert_equal klass::DISCRIMINATOR, ix.data.first(8)
    end

    it 'data encodes a None settings_authority as a single zero byte' do
      assert_equal 0, ix.data[8]
    end

    it 'data encodes threshold as a little-endian u16' do
      assert_equal [1, 0], ix.data[9, 2]
    end
  end

  describe '.data' do
    let(:pubkey) { 'GqH8rytYU4AtEePST5x1JvgDTYZtVGoSbZ5zRZU2vPDh' }

    it 'encodes a Some settings_authority correctly' do
      data = klass.data(
        settings_authority: pubkey,
        threshold:          1,
        signers:            [],
        time_lock:          0,
        rent_collector:     nil,
        memo:               nil
      )

      # Option<publicKey> Some discriminant
      assert_equal 1, data[8]
      # Followed by the 32-byte pubkey
      assert_equal Solace::Utils::Codecs.base58_to_bytes(pubkey), data[9, 32]
    end

    it 'encodes memo as None when nil' do
      data = klass.data(
        settings_authority: nil,
        threshold:          1,
        signers:            [],
        time_lock:          0,
        rent_collector:     nil,
        memo:               nil
      )

      assert_equal 0, data.last
    end
  end
end
