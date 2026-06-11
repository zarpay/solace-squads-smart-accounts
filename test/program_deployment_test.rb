# frozen_string_literal: true

require_relative 'test_helper'

# Verifies that the Squads Smart Account program is present and executable on
# the local test validator. If this test fails, the validator likely did not
# clone the program successfully on startup.
describe 'Squads Smart Account program deployment' do
  before do
    @connection = Solace::Connection.new
  end

  it 'has an account at the program ID' do
    account = @connection.get_account_info(Solace::SquadsSmartAccounts::PROGRAM_ID)

    refute_nil account, 'Expected program account to exist on local validator'
  end

  it 'is marked as executable' do
    account = @connection.get_account_info(Solace::SquadsSmartAccounts::PROGRAM_ID)

    assert account['executable'], 'Expected program account to be executable'
  end
end
