# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module Rake
  module Handlers
    # Compares the upstream IDL for the Squads Smart Account program (fetched
    # directly from the canonical GitHub source) against the local IDL file
    # checked into this repository. Useful for detecting program upgrades that
    # require updating the local copy.
    module IDLCompare
      extend self

      # Absolute path to the project root, derived from this file's location
      # (rake/handlers/ → up two levels).
      PROJECT_ROOT = File.expand_path('../..', __dir__)

      # Canonical IDL source — raw JSON from the upstream GitHub repository.
      UPSTREAM_IDL_URL = 'https://raw.githubusercontent.com/Squads-Protocol/' \
                         'smart-account-program/refs/heads/main/idl/' \
                         'squads_smart_account_program.json'

      # Fetches the upstream IDL and compares it to the local copy, printing a
      # pass/fail result to stdout.
      #
      # @return [void]
      def run
        upstream_idl = fetch_upstream_idl
        local_idl    = fetch_local_idl

        if upstream_idl == local_idl
          puts '✅ Success: Upstream IDL matches local IDL.'
        else
          puts '❌ Mismatch: Upstream IDL and local IDL are different.'
        end
      end

      private

      # Fetches and parses the IDL JSON from the upstream GitHub repository.
      # Follows HTTP redirects and exits with a non-zero status on failure.
      #
      # @return [Hash] Parsed IDL as a Ruby hash.
      def fetch_upstream_idl
        puts "Fetching upstream IDL from #{UPSTREAM_IDL_URL}..."

        uri      = URI.parse(UPSTREAM_IDL_URL)
        response = Net::HTTP.get_response(uri)

        # Follow a single redirect (raw.githubusercontent.com can redirect).
        if response.is_a?(Net::HTTPRedirection)
          uri      = URI.parse(response['location'])
          response = Net::HTTP.get_response(uri)
        end

        unless response.is_a?(Net::HTTPSuccess)
          abort "Error fetching upstream IDL: HTTP #{response.code} #{response.message}"
        end

        JSON.parse(response.body)
      end

      # Reads and parses the local IDL file bundled with this gem.
      #
      # @return [Hash] Parsed IDL as a Ruby hash.
      # @raise [SystemExit] if the local IDL file does not exist.
      def fetch_local_idl
        # Build the path from the project root so it resolves correctly
        # regardless of the working directory when rake is invoked.
        local_idl_path = File.join(
          PROJECT_ROOT,
          'lib/solace/squads_smart_accounts/idl/squads_smart_account_program.json'
        )

        abort "Error: Local IDL not found at #{local_idl_path}" unless File.exist?(local_idl_path)

        JSON.parse(File.read(local_idl_path))
      end
    end
  end
end
