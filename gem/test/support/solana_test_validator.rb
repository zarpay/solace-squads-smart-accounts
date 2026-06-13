# frozen_string_literal: true

# Spins up a Solana test validator with the Squads Smart Account program cloned
# from mainnet-beta. Executed at require time by test_helper.rb; tears down via
# Minitest.after_run when the test suite finishes.

# Full command passed to Process.spawn — clones the Squads program and its
# global program config account from mainnet-beta so integration tests run
# against the real program bytecode and config state (treasury address, fees).
# --reset starts from a fresh ledger every run: state never persists between
# runs, so there is no ledger replay to race against and no stale state to
# inherit from an uncleanly stopped validator. Fixture accounts are re-funded
# at suite start by support/bootstrap.rb.
SQUADS_VALIDATOR_CMD = [
  'solana-test-validator',
  '--reset',
  '--clone-upgradeable-program', Solace::SquadsSmartAccounts::PROGRAM_ID,
  '--clone', Solace::SquadsSmartAccounts::PROGRAM_CONFIG_ADDRESS,
  '--url', 'mainnet-beta'
].freeze

# Log destinations — written to /tmp so the project tree stays clean.
SQUADS_VALIDATOR_LOG = '/tmp/solace-squads-validator.log'
SQUADS_VALIDATOR_ERR = '/tmp/solace-squads-validator.err.log'

# If a validator is already running (e.g. left over from a previous dev run),
# skip starting a new one. Exclude the grep process itself and any defunct
# (zombie) processes that may linger after a previous test run.
@validator_pid = `ps aux | grep 'solana-test-val' | grep -v grep | grep -v defunct`.strip

return unless @validator_pid.empty?

@started_validator = true

@solana_validator_pid = Process.spawn(
  *SQUADS_VALIDATOR_CMD,
  out: SQUADS_VALIDATOR_LOG,
  err: SQUADS_VALIDATOR_ERR
)

puts "[SquadsValidator] Validator started on PID #{@solana_validator_pid}."

# Poll the RPC endpoint until the validator is accepting connections.
def validator_started?
  Solace::Connection.new.get_latest_blockhash[0]
  true
rescue Errno::ECONNREFUSED
  false
end

until validator_started?
  puts '[SquadsValidator] Waiting for first blockhash...'
  sleep 1
end

puts '[SquadsValidator] Ready.'

# Terminate the validator only if this process started it.
Minitest.after_run do
  next unless @started_validator

  Process.kill('TERM', @solana_validator_pid)
  Process.wait(@solana_validator_pid)

  puts "\n[SquadsValidator] Validator stopped."
end
