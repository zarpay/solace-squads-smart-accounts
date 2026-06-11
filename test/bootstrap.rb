# frozen_string_literal: true

# Bootstrap script — funds fixture accounts on the local test validator.
# Run once before the test suite: `bundle exec rake bootstrap`
# Safe to re-run: airdrops are idempotent (just adds more SOL).

require_relative 'test_helper'

include Solace::SquadsSmartAccounts::Test

BOOTSTRAP_LAMPORTS = 10_000_000_000 # 10 SOL per fixture account

connection = Solace::Connection.new

# Fund each fixture keypair.
[
  Fixtures.load_keypair('creator')
].each do |keypair|
  print "Funding #{keypair.address}... "

  sig = connection.request_airdrop(keypair.address, BOOTSTRAP_LAMPORTS)

  # Wait for finalization so the airdrop survives a validator restart —
  # the validator is killed right after bootstrap, and merely confirmed
  # transactions can be dropped from the replayed ledger.
  connection.wait_for_confirmed_signature('finalized') { sig['result'] }

  balance = connection.get_balance(keypair.address)
  puts "done (#{balance} lamports)"
end

puts 'Bootstrap complete.'
