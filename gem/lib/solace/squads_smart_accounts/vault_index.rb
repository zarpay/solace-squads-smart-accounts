# frozen_string_literal: true

require 'fileutils'

module Solace
  module SquadsSmartAccounts
    # Reverse lookup from a smart-account (vault) address back to its index and
    # settings address.
    #
    # Vault addresses are derived one-way from an index (settings_seed), so the only
    # way to invert the mapping is to precompute it. This builds a compact on-disk
    # table — one 32-byte vault pubkey per record, where the record at 0-based offset
    # `o` is the default vault (account_index 0) of `settings_seed = o + 1` — and
    # queries it.
    #
    # @example Build once, then look up
    #   VaultIndex.build(count: 500_000)
    #   VaultIndex.lookup(vault_address) # => { index: 1500, settings_address: "41gq..." }
    #
    # Caveats: the table is a snapshot covering indices `1..count`, so an address with a
    # higher index (or created after the build) is not found — rebuild with a larger
    # `count` to extend. Only the default vault (account_index 0) is indexed.
    module VaultIndex
      extend self

      # Bytes per record — a raw ed25519 public key.
      RECORD_SIZE = 32

      # Default table filename, written in the current working directory (wherever the
      # caller runs from). Pass `path:` to {build}/{lookup} to put it elsewhere.
      DEFAULT_FILENAME = 'vault-index.bin'

      # @return [String] The default table path: DEFAULT_FILENAME in the current directory.
      def default_path
        File.join(Dir.pwd, DEFAULT_FILENAME)
      end

      # Derives the default vault for each seed in 1..count and writes the raw pubkeys
      # to `path`. The write is atomic, so an interrupted build leaves no partial cache.
      #
      # @param count [Integer] Number of indices to cover (seeds 1..count).
      # @param path [String] Output file path (default: {default_path}).
      # @param progress [Proc, nil] Optional `progress.call(done, count)`, every 50k seeds.
      # @return [String] The path written.
      def build(count: 500_000, path: default_path, progress: nil)
        write_atomically(path) do |io|
          (1..count).each do |seed|
            io.write(default_vault_pubkey(seed))
            progress&.call(seed, count) if (seed % 50_000).zero?
          end
        end
        path
      end

      # Resolves a vault address to its index and settings address.
      #
      # @param vault_address [#to_s] The smart-account (vault) address.
      # @param path [String] The table file path (default: {default_path}).
      # @return [Hash, nil] `{ index:, settings_address: }`, or nil if not in the table.
      # @raise [RuntimeError] If the table file does not exist.
      def lookup(vault_address, path: default_path)
        seed = table(path)[packed_pubkey(vault_address)]
        return unless seed

        settings_address, = settings_for(seed)
        { index: seed, settings_address: }
      end

      private

      # The packed 32-byte vault pubkey for a settings seed's default vault.
      def default_vault_pubkey(seed)
        settings_address, = settings_for(seed)
        vault_address,    = Solace::Programs::SquadsSmartAccount.get_smart_account_address(settings_address:)
        packed_pubkey(vault_address)
      end

      # Derives the settings PDA for a seed. Returns [address, bump].
      def settings_for(seed)
        Solace::Programs::SquadsSmartAccount.get_settings_address(settings_seed: seed)
      end

      # A base58 address as its raw 32-byte binary string (the table's key/record form).
      def packed_pubkey(address)
        Solace::Utils::Codecs.base58_to_bytes(address.to_s).pack('C*')
      end

      # The lookup table for `path` as a Hash{ packed pubkey => seed }, loaded once per path.
      def table(path)
        (@tables ||= {})[path] ||= load_table(path)
      end

      def load_table(path)
        raise "Vault index not found at #{path}. Build it first with VaultIndex.build." unless File.exist?(path)

        data = File.binread(path)
        (0...(data.bytesize / RECORD_SIZE)).to_h do |offset|
          [data.byteslice(offset * RECORD_SIZE, RECORD_SIZE), offset + 1]
        end
      end

      # Writes via a temp file and renames into place so the cache is never half-written.
      def write_atomically(path, &)
        FileUtils.mkdir_p(File.dirname(path))
        tmp = "#{path}.#{Process.pid}.tmp"
        File.open(tmp, 'wb', &)
        File.rename(tmp, path)
      ensure
        FileUtils.rm_f(tmp)
      end
    end
  end
end
