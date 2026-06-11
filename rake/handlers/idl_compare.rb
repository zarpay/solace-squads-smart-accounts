# frozen_string_literal: true

module Rake
  module Handlers
    # Task handler for comparing onchain_idl for Squads Smart Accounts to local_idl.
    module IDLCompare
      extend self

      def run(
        cluster = 'mainnet',
        program_id = 'SMRTzfY6DfH5ik3TKiyLFfXexV8uSG3d2UksSCYdunG'
      )
        onchain_idl = fetch_onchain_idl(cluster, program_id)
        local_idl   = fetch_local_idl

        if onchain_idl == local_idl
          puts '✅ Success: Onchain IDL matches local IDL.'
        else
          puts '❌ Mismatch: Onchain IDL and local IDL are different.'
        end
      end

      private

      def fetch_onchain_idl(cluster, program_id)
        # Check if anchor is installed
        _, status = Open3.capture2e('command -v anchor')
        unless status.success?
          puts "Warning: 'anchor' CLI not found. Cannot fetch onchain IDL."
          exit(1)
        end

        puts "Fetching IDL for Program: #{program_id} on #{cluster}..."

        _, stderr, fetch_status = Open3.capture3("anchor idl fetch #{program_id} --provider.cluster #{cluster}")
        return JSON.parse(stdout) if fetch_status.success?

        puts "Error fetching IDL: #{stderr.strip}"
        exit(1)
      end

      def fetch_local_idl
        local_idl_path = File.expand_path('lib/solace/squads_smart_accounts/idl/squads.json', __dir__)

        abort "Error: Local IDL not found at #{local_idl_path}" unless File.exist?(local_idl_path)

        JSON.parse(File.read(local_idl_path))
      end
    end
  end
end
