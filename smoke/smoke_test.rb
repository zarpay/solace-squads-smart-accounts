# frozen_string_literal: true

# Consumer sanity check: proves a host app can install the gem, require it with a
# single statement, and reach both this gem's classes and its solace dependency —
# all offline (no validator or network). Run with:
#
#   cd smoke && bundle install && bundle exec ruby smoke_test.rb

require 'minitest/autorun'

# A single require must load the gem AND pull in solace transitively.
require 'solace/squads_smart_accounts'

class ConsumerSmokeTest < Minitest::Test
  def test_solace_dependency_is_loaded_transitively
    assert defined?(Solace::Keypair), 'solace should load via the gem dependency'
    assert defined?(Solace::Connection)
  end

  def test_gem_classes_are_defined
    assert defined?(Solace::Programs::SquadsSmartAccount)
    assert defined?(Solace::Composers::SquadsSmartAccountsCreateSmartAccountComposer)
    assert defined?(Solace::SquadsSmartAccounts::Instructions::CreateSmartAccountInstruction)
  end

  def test_permission_masks_compute_as_documented
    perms = Solace::SquadsSmartAccounts::Permissions

    assert_equal 0b111, perms::ALL
    assert_equal 0b011, perms.mask(:initiate, :vote)
  end

  def test_pda_derivation_works_offline
    # Pure local crypto (no connection) — exercises the solace integration end to end.
    address, bump = Solace::Programs::SquadsSmartAccount.get_settings_address(settings_seed: 1)

    assert_kind_of String, address
    assert_includes 0..255, bump
  end
end
