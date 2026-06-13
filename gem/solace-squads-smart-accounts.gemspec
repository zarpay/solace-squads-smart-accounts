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
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Packaged files are the library only; README/LICENSE/CHANGELOG live at the repo root.
  spec.files         = Dir.glob('lib/**/*').reject { |path| File.directory?(path) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'solace'
  spec.add_dependency 'solana-program-library' # Assuming we might need SDLS or similar if needed, but let's keep it minimal for now

  # Development dependencies
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'solana-test-validator' # If available as a gem or we use system calls
end
