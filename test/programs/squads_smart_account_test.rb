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
end
