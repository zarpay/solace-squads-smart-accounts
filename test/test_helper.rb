# frozen_string_literal: true

# test/test_helper.rb

require 'bundler'
require 'minitest/autorun'
require 'minitest/hooks/default'

# Ensure we can find the 'solace' gem if it's not installed
$LOAD_PATH.unshift(File.expand_path(ENV['SOLACE_PATH'], __dir__)) if ENV['SOLACE_PATH']

require 'solace/squads_smart_accounts'

require_relative 'support/solana_test_validator'
# Add other supports as needed
