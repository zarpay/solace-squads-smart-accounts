# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::SmartAccountIdentity do
  let(:settings_seed) { 42 }

  let(:settings_address) do
    Solace::Programs::SquadsSmartAccount.get_settings_address(settings_seed:).first
  end

  let(:smart_account_address) do
    Solace::Programs::SquadsSmartAccount.get_smart_account_address(settings_address:).first
  end

  let(:identity) do
    Solace::SquadsSmartAccounts::SmartAccountIdentity.new(
      settings_seed:,
      settings_address:,
      smart_account_address:
    )
  end

  it 'exposes the settings seed' do
    assert_equal settings_seed, identity.settings_seed
  end

  it 'exposes the settings address' do
    assert_equal settings_address, identity.settings_address
  end

  it 'exposes the smart account address' do
    assert_equal smart_account_address, identity.smart_account_address
  end

  it 'is frozen' do
    assert_predicate identity, :frozen?
  end
end
