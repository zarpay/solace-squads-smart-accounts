# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::Programs::SquadsSmartAccount do
  let(:klass) { Solace::Programs::SquadsSmartAccount }
  let(:connection) { Solace::Connection.new }
  let(:program) { klass.new(connection: connection) }

  describe '#initialize' do
    it 'assigns connection' do
      assert_equal connection, program.connection
    end

    it 'assigns the Squads Smart Account program id' do
      assert_equal Solace::SquadsSmartAccounts::PROGRAM_ID, program.program_id
    end
  end

  describe '.get_settings_address' do
    let(:settings_seed) { 42 }

    it 'derives the settings PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', 'settings', Solace::Utils::Codecs.encode_le_u128(settings_seed).bytes],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_settings_address(settings_seed: settings_seed)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'is available as an instance method' do
      assert_equal klass.get_settings_address(settings_seed: settings_seed),
                   program.get_settings_address(settings_seed: settings_seed)
    end
  end

  describe '.get_smart_account_address' do
    let(:settings_address) { klass.get_settings_address(settings_seed: 42).first }

    it 'derives the vault PDA from the documented seeds' do
      expected_address, expected_bump = Solace::Utils::PDA.find_program_address(
        ['smart_account', settings_address, 'smart_account', [0]],
        Solace::SquadsSmartAccounts::PROGRAM_ID
      )

      address, bump = klass.get_smart_account_address(settings_address: settings_address)

      assert_equal expected_address, address
      assert_equal expected_bump, bump
    end

    it 'defaults account_index to 0' do
      assert_equal klass.get_smart_account_address(settings_address: settings_address, account_index: 0),
                   klass.get_smart_account_address(settings_address: settings_address)
    end

    it 'derives different addresses for different account indexes' do
      address_zero, = klass.get_smart_account_address(settings_address: settings_address)
      address_one,  = klass.get_smart_account_address(settings_address: settings_address, account_index: 1)

      refute_equal address_zero, address_one
    end

    it 'is available as an instance method' do
      assert_equal klass.get_smart_account_address(settings_address: settings_address),
                   program.get_smart_account_address(settings_address: settings_address)
    end
  end
end
