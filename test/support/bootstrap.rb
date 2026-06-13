# frozen_string_literal: true

# Funds the fixture accounts and creates the shared token mints on the local
# test validator. Executed at require time by test_helper.rb, after the
# validator is ready. The validator ledger is reset on every run, so funding
# only waits for confirmation and the mints are (re)created unconditionally —
# nothing needs to survive a restart. Airdrops are idempotent.

BOOTSTRAP_LAMPORTS = 10_000_000_000 # 10 SOL per fixture account
BOOTSTRAP_MINT_DECIMALS = 6 # shared decimals for both fixture mints

@bootstrap_connection = Solace::Connection.new

# Fund the keypair fixtures that pay fees and act as authorities.
%w[creator payer mint-authority].each do |name|
  keypair = Solace::SquadsSmartAccounts::Test::Fixtures.load_keypair(name)

  signature = @bootstrap_connection.request_airdrop(keypair.address, BOOTSTRAP_LAMPORTS)
  @bootstrap_connection.wait_for_confirmed_signature { signature['result'] }

  puts "[Bootstrap] Funded #{keypair.address}."
end

# Create the SPL Token and Token-2022 mints at their fixture addresses. The mint
# keypairs are fixtures so their addresses are stable across runs; the
# mint-authority fixture is the mint + freeze authority for both.
@bootstrap_payer = Solace::SquadsSmartAccounts::Test::Fixtures.load_keypair('payer')
@bootstrap_mint_authority = Solace::SquadsSmartAccounts::Test::Fixtures.load_keypair('mint-authority')

{
  'spl-mint' => Solace::Programs::SplToken.new(connection: @bootstrap_connection),
  'token-2022-mint' => Solace::Programs::Token2022.new(connection: @bootstrap_connection)
}.each do |fixture_name, token_program|
  mint_keypair = Solace::SquadsSmartAccounts::Test::Fixtures.load_keypair(fixture_name)

  tx = token_program.create_mint(
    payer:          @bootstrap_payer,
    funder:         @bootstrap_payer,
    decimals:       BOOTSTRAP_MINT_DECIMALS,
    mint_authority: @bootstrap_mint_authority,
    mint_account:   mint_keypair
  )
  @bootstrap_connection.wait_for_confirmed_signature { tx.signature }

  puts "[Bootstrap] Created mint #{mint_keypair.address} (#{fixture_name})."
end
