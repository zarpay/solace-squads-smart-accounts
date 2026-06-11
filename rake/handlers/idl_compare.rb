# frozen_string_literal: true

require 'json'
require 'open3'
require_relative '../../lib/solace/squads_smart_accounts/constants'

module Rake
  module Handlers
    # Compares the on-chain Anchor IDL for the Squads Smart Account program
    # against the local IDL file checked into this repository. Useful for
    # detecting program upgrades that require updating the local copy.
    module IDLCompare
      extend self

      # Absolute path to the project root, derived from this file's location
      # (rake/handlers/ → up two levels).
      PROJECT_ROOT = File.expand_path('../..', __dir__)

      # Runs the comparison and prints a pass/fail result to stdout.
      #
      # @param cluster [String] Solana cluster name passed to `anchor idl fetch`
      #   (e.g. 'mainnet', 'devnet').
      # @param program_id [String] Base58 program ID to fetch the IDL for.
      # @return [void]
      def run(cluster, program_id)
        onchain_idl = fetch_onchain_idl(cluster, program_id)
        local_idl   = fetch_local_idl

        if onchain_idl == local_idl
          puts '✅ Success: Onchain IDL matches local IDL.'
        else
          puts '❌ Mismatch: Onchain IDL and local IDL are different.'
        end
      end

      private

      # Fetches and parses the IDL from the deployed on-chain program using the
      # Anchor CLI. Exits with a non-zero status if `anchor` is not installed or
      # the fetch fails.
      #
      # @param cluster [String] Solana cluster name (e.g. 'mainnet', 'devnet').
      # @param program_id [String] Base58 program ID to fetch.
      # @return [Hash] Parsed IDL as a Ruby hash.
      def fetch_onchain_idl(cluster, program_id)
        # Verify the anchor CLI is available before attempting a network call.
        _, status = Open3.capture2e('command -v anchor')
        unless status.success?
          puts "Warning: 'anchor' CLI not found. Cannot fetch onchain IDL."
          exit(1)
        end

        puts "Fetching IDL for Program: #{program_id} on #{cluster}..."

        # capture3 returns [stdout, stderr, process_status].
        stdout, stderr, fetch_status = Open3.capture3(
          "anchor idl fetch #{program_id} --provider.cluster #{cluster}"
        )

        unless fetch_status.success?
          puts "Error fetching IDL: #{stderr.strip}"
          exit(1)
        end

        JSON.parse(stdout)
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
