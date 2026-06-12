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

  # Grants a SOL spending limit on an existing controlled smart account and
  # waits for confirmation. The authority pays all fees and rent.
  #
  # @param program [Solace::Programs::SquadsSmartAccount] The program client.
  # @param identity [Solace::SquadsSmartAccounts::SmartAccountIdentity] The smart account.
  # @param authority [Solace::Keypair] The settings authority (also pays).
  # @param delegate [#to_s] The key allowed to use the limit.
  # @param amount [Integer] Lamports spendable per period.
  # @param period [Integer] Period enum value.
  # @return [String] The spending limit PDA address.
  def grant_spending_limit(program, identity:, authority:, delegate:, amount:, period:)
    seed = Solace::Keypair.generate

    spending_limit_address, = program.get_spending_limit_address(
      settings_address: identity.settings_address,
      seed:
    )

    tx = program.add_spending_limit_as_authority(
      payer:              authority,
      settings:           identity.settings_address,
      settings_authority: authority,
      rent_payer:         authority,
      spending_limit:     spending_limit_address,
      seed:,
      amount:,
      period:,
      signers:            [delegate.to_s]
    )
    program.connection.wait_for_confirmed_signature { tx.signature }

    spending_limit_address
  end

  # Airdrops lamports to an address and waits for confirmation.
  #
  # @param connection [Solace::Connection] An active RPC connection.
  # @param address [#to_s] The address to fund.
  # @param lamports [Integer] The amount to airdrop.
  # @return [void]
  def fund_account(connection, address, lamports)
    signature = connection.request_airdrop(address.to_s, lamports)
    connection.wait_for_confirmed_signature { signature['result'] }
  end
end

# Make all helpers available as bare method calls in every test.
Minitest::Test.include Helpers
