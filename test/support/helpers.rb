# frozen_string_literal: true

# Shared helpers for integration test setup. Included into Minitest::Test
# below, so all methods are callable directly inside any test or describe block.
module Helpers
  # Creates a smart account, waits for confirmation, and returns its identity.
  #
  # Wraps Programs::SquadsSmartAccount#create_smart_account for tests that
  # need a smart account as setup rather than as the subject under test.
  #
  # @param program [Solace::Programs::SquadsSmartAccount] The program client.
  # @param payer [Solace::Keypair] The keypair paying fees, rent, and the creation fee.
  # @param composer_opts [Hash] Options for #compose_create_smart_account
  #   (creator:, threshold:, signers:, time_lock:, ...).
  # @return [Solace::SquadsSmartAccounts::SmartAccountIdentity] The created smart account's identity.
  def create_smart_account(program, payer:, **composer_opts)
    identity = program.next_smart_account

    tx = program.create_smart_account(
      payer:,
      settings_seed: identity.settings_seed,
      **composer_opts
    )

    program.connection.wait_for_confirmed_signature { tx.signature }

    identity
  end
end

# Make all helpers available as bare method calls in every test.
Minitest::Test.include Helpers
