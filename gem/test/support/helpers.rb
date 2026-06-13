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
  # @param amount [Integer] Amount spendable per period (mint decimals).
  # @param period [Integer] Period enum value.
  # @param mint [#to_s] The token mint (defaults to DEFAULT_PUBKEY = SOL).
  # @return [String] The spending limit PDA address.
  def grant_spending_limit(
    program,
    identity:,
    authority:,
    delegate:,
    amount:, period:,
    mint: Solace::SquadsSmartAccounts::DEFAULT_PUBKEY
  )
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
      mint:,
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

  # Derives an owner's associated token account, creating it on-chain if absent.
  #
  # @param connection [Solace::Connection] An active RPC connection.
  # @param payer [Solace::Keypair] Pays fees and rent for the ATA.
  # @param owner [#to_s] The ATA owner (may be an off-curve PDA like a vault).
  # @param mint [#to_s] The token mint.
  # @param token_program_id [String] The program owning the mint.
  # @return [String] The associated token account address.
  def create_ata(connection, payer:, owner:, mint:, token_program_id:)
    Solace::Programs::AssociatedTokenAccount.new(connection:).get_or_create_address(
      payer:,
      funder:           payer,
      owner:            owner.to_s,
      mint:             mint.to_s,
      token_program_id:
    )
  end

  # Mints tokens to a destination token account and waits for confirmation.
  #
  # @param token_program [Solace::Programs::SplToken, Solace::Programs::Token2022] The token client.
  # @param payer [Solace::Keypair] Pays the transaction fee.
  # @param mint [#to_s] The token mint.
  # @param destination [#to_s] The destination token account (ATA).
  # @param amount [Integer] The amount to mint (mint decimals).
  # @param authority [Solace::Keypair] The mint authority (signs).
  # @return [void]
  def mint_tokens(token_program, payer:, mint:, destination:, amount:, authority:)
    tx = token_program.mint_to(
      payer:,
      mint:           mint.to_s,
      destination:    destination.to_s,
      amount:,
      mint_authority: authority
    )
    token_program.connection.wait_for_confirmed_signature { tx.signature }
  end
end

# Make all helpers available as bare method calls in every test.
Minitest::Test.include Helpers
