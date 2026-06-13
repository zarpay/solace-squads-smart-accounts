# frozen_string_literal: true

require_relative '../test_helper'

describe Solace::SquadsSmartAccounts::Permissions do
  let(:permissions) { Solace::SquadsSmartAccounts::Permissions }

  describe 'constants' do
    it 'defines INITIATE as the first bit' do
      assert_equal 0b001, permissions::INITIATE
    end

    it 'defines VOTE as the second bit' do
      assert_equal 0b010, permissions::VOTE
    end

    it 'defines EXECUTE as the third bit' do
      assert_equal 0b100, permissions::EXECUTE
    end

    it 'defines ALL as the union of all three permissions' do
      assert_equal 0b111, permissions::ALL
    end
  end

  describe '.mask' do
    it 'builds a mask from a single permission name' do
      assert_equal permissions::INITIATE, permissions.mask(:initiate)
    end

    it 'combines multiple permission names' do
      assert_equal permissions::INITIATE | permissions::VOTE, permissions.mask(:initiate, :vote)
    end

    it 'accepts :all' do
      assert_equal permissions::ALL, permissions.mask(:all)
    end

    it 'returns 0 for no names' do
      assert_equal 0, permissions.mask
    end

    it 'raises ArgumentError for an unknown permission name' do
      error = assert_raises(ArgumentError) { permissions.mask(:approve) }

      assert_equal 'unknown permission: :approve', error.message
    end
  end
end
