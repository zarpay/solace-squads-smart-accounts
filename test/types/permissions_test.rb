# frozen_string_literal: true

require_relative '../test_helper'

include Solace::SquadsSmartAccounts

describe Permissions do
  describe 'constants' do
    it 'defines INITIATE as the first bit' do
      assert_equal 0b001, Permissions::INITIATE
    end

    it 'defines VOTE as the second bit' do
      assert_equal 0b010, Permissions::VOTE
    end

    it 'defines EXECUTE as the third bit' do
      assert_equal 0b100, Permissions::EXECUTE
    end

    it 'defines ALL as the union of all three permissions' do
      assert_equal 0b111, Permissions::ALL
    end
  end

  describe '.mask' do
    it 'builds a mask from a single permission name' do
      assert_equal Permissions::INITIATE, Permissions.mask(:initiate)
    end

    it 'combines multiple permission names' do
      assert_equal Permissions::INITIATE | Permissions::VOTE, Permissions.mask(:initiate, :vote)
    end

    it 'accepts :all' do
      assert_equal Permissions::ALL, Permissions.mask(:all)
    end

    it 'returns 0 for no names' do
      assert_equal 0, Permissions.mask
    end

    it 'raises ArgumentError for an unknown permission name' do
      error = assert_raises(ArgumentError) { Permissions.mask(:approve) }

      assert_equal 'unknown permission: :approve', error.message
    end
  end
end
