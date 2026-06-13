# frozen_string_literal: true

require_relative 'lib/solace/squads_smart_accounts/version'

Gem::Specification.new do |spec|
  spec.name          = 'solace-squads-smart-accounts'
  spec.version       = Solace::SquadsSmartAccounts::VERSION
  spec.authors       = ['Sebastian Scholl']
  spec.email         = ['sebscholl@gmail.com']
  spec.summary       = 'Solana Squads Smart Accounts extension for Solace'
  spec.description   = 'Instructions and composers to interact with Squads Smart Accounts on Solana using the Solace gem.'
  spec.homepage      = 'https://github.com/zarpay/solace-squads-smart-accounts'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1'

  spec.metadata['allowed_push_host']     = 'https://rubygems.org'
  spec.metadata['source_code_uri']       = 'https://github.com/zarpay/solace-squads-smart-accounts'
  spec.metadata['changelog_uri']         = 'https://github.com/zarpay/solace-squads-smart-accounts/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri']     = 'https://zarpay.github.io/solace-squads-smart-accounts'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Packaged files are the library only; README/LICENSE/CHANGELOG live at the repo root.
  spec.files         = Dir.glob('lib/**/*').reject { |path| File.directory?(path) }
  spec.require_paths = ['lib']

  # Runtime dependencies.
  #
  # The solace constraint is intentionally open-ended (no upper bound) so a host app can
  # track newer solace releases without a version conflict; 0.1.5 is the floor — it
  # introduced Solace::Programs::Token2022, which this gem relies on.
  #
  # base64 is exercised through solace's account decoding (base64_to_bytestream) and is
  # not a default gem on Ruby 3.4+, so we declare it to keep the gem self-sufficient.
  spec.add_dependency 'base64'
  spec.add_dependency 'solace', '>= 0.1.5'

  # Development dependencies.
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'minitest-hooks', '~> 1.5'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-yard'
end
