# frozen_string_literal: true

require_relative '../test/test_helper'

class TestSetup < Minitest::Test
  def test_version
    assert_equal '0.1.0', Solace::SquadsSmartAccounts::VERSION
  end

  def test_module_const
    assert_equal Solace::SquadsSmartAccounts, Solace::SquadsSmartAccounts
  end
end
