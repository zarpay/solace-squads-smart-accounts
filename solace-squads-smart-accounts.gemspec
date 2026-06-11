# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'solace-squads-smart-accounts'
  spec.version       = '0.1.0'
  spec.authors       = ['Sebastian Scholl']
  spec.email         = ['sebscholl@gmail.com']
  spec.summary       = 'Solana Squads Smart Accounts extension for Solace'
  spec.description   = 'Instructions and composers to interact with Squads Smart Accounts on Solana using the Solace gem.'
  spec.homepage      = 'https://github.com/sebscholl/solace-squads-smart-accounts'
  spec.license       = 'MIT'

  spec.files         = Dir[
    'lib/**/*',
    'README.md',
    'LICENSE',
    'CHANGELOG'
  ]
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'solace'
  spec.add_dependency 'solana-program-library' # Assuming we might need SDLS or similar if needed, but let's keep it minimal for now

  # Development dependencies
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'solana-test-validator' # If available as a gem or we use system calls

  spec.required_ruby_version = '>= 3.0'
end
