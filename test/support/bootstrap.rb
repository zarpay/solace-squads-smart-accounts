# frozen_string_literal: true

# Funds the fixture accounts on the local test validator. Executed at require
# time by test_helper.rb, after the validator is ready. The validator ledger is
# reset on every run, so funding only waits for confirmation — nothing needs
# to survive a restart. Airdrops are idempotent (re-running just adds more SOL).

BOOTSTRAP_LAMPORTS = 10_000_000_000 # 10 SOL per fixture account

@bootstrap_connection = Solace::Connection.new

%w[creator payer].each do |name|
  keypair = Solace::SquadsSmartAccounts::Test::Fixtures.load_keypair(name)

  signature = @bootstrap_connection.request_airdrop(keypair.address, BOOTSTRAP_LAMPORTS)
  @bootstrap_connection.wait_for_confirmed_signature { signature['result'] }

  puts "[Bootstrap] Funded #{keypair.address}."
end
