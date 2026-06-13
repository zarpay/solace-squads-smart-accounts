# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# Offline round-trip for the reverse vault-address lookup — pure PDA derivation,
# no validator or network.
describe Solace::SquadsSmartAccounts::VaultIndex do
  let(:klass) { Solace::SquadsSmartAccounts::VaultIndex }
  let(:program) { Solace::Programs::SquadsSmartAccount }
  let(:count) { 200 }

  before(:all) do
    @dir  = Dir.mktmpdir
    @path = File.join(@dir, 'vault-index.bin')
    Solace::SquadsSmartAccounts::VaultIndex.build(count: 200, path: @path)
  end

  after(:all) do
    FileUtils.remove_entry(@dir) if @dir
  end

  it 'writes one 32-byte record per index' do
    assert_equal count * 32, File.size(@path)
  end

  it 'resolves a known vault to its settings index' do
    settings, = program.get_settings_address(settings_seed: 137)
    vault,    = program.get_smart_account_address(settings_address: settings)

    assert_equal 137, klass.lookup(vault, path: @path)[:index]
  end

  it 'resolves a known vault to its settings address' do
    settings, = program.get_settings_address(settings_seed: 137)
    vault,    = program.get_smart_account_address(settings_address: settings)

    assert_equal settings, klass.lookup(vault, path: @path)[:settings_address]
  end

  it 'returns nil for an address not in the table' do
    assert_nil klass.lookup(Solace::Keypair.generate.address, path: @path)
  end

  it 'raises a clear error when the table file is missing' do
    error = assert_raises(RuntimeError) do
      klass.lookup(Solace::Keypair.generate.address, path: File.join(@dir, 'missing.bin'))
    end

    assert_match(/build it/i, error.message)
  end
end
