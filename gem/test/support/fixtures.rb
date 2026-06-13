# frozen_string_literal: true

require 'json'

module Solace
  module SquadsSmartAccounts
    module Test
      # Loads pre-generated keypair fixtures from test/fixtures/*.json.
      # Each fixture file contains a 64-byte array (private key + public key).
      # Fixtures are funded once via `rake bootstrap` and reused across test runs.
      module Fixtures
        # Path to the fixtures directory.
        FIXTURES_PATH = File.expand_path('../fixtures', __dir__)

        # Loads a keypair fixture by name.
        #
        # @param name [String] The fixture filename without extension (e.g. 'creator').
        # @return [Solace::Keypair] The loaded keypair.
        def self.load_keypair(name)
          raw = JSON.parse(File.read(File.join(FIXTURES_PATH, "#{name}.json")))
          Solace::Keypair.from_secret_key(raw.pack('C*'))
        end
      end
    end
  end
end
