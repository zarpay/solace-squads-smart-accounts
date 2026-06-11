# frozen_string_literal: true

require 'digest'

module Solace
  module Utils
    # Extensions to Solace::Utils::Codecs for Anchor programs and Borsh types not
    # covered by the base gem. Candidates for upstreaming to solace when the need
    # is confirmed across other extension gems.
    module Codecs
      # Computes the 8-byte Anchor instruction discriminator for a given instruction name.
      # Anchor derives discriminators from the snake_case name regardless of how the
      # instruction is named in the IDL (which uses camelCase).
      #
      # @param instruction_name [String] The instruction name in camelCase or snake_case
      #   (e.g. 'createSmartAccount' or 'create_smart_account').
      # @return [Array<Integer>] 8-byte discriminator array.
      def self.anchor_discriminator(instruction_name)
        # Convert camelCase to snake_case to match Anchor's internal naming.
        snake = instruction_name.gsub(/([A-Z])/) { "_#{$1.downcase}" }.sub(/\A_/, '')
        Digest::SHA256.digest("global:#{snake}").bytes.first(8)
      end

      # Encodes a u16 as 2 little-endian bytes.
      #
      # @param u16 [Integer] Value in range 0..65535.
      # @return [String] 2-byte little-endian binary string.
      def self.encode_le_u16(u16)
        [u16].pack('S<')
      end

      # Encodes a u32 as 4 little-endian bytes.
      #
      # @param u32 [Integer] Value in range 0..4294967295.
      # @return [String] 4-byte little-endian binary string.
      def self.encode_le_u32(u32)
        [u32].pack('L<')
      end

      # Encodes a u128 as 16 little-endian bytes (two u64 words, low word first).
      #
      # @param u128 [Integer] Value in range 0..2**128-1.
      # @return [String] 16-byte little-endian binary string.
      def self.encode_le_u128(u128)
        [u128 & 0xFFFFFFFFFFFFFFFF, u128 >> 64].pack('Q<Q<')
      end

      # Encodes an Option<publicKey> in Borsh format.
      # None → [0], Some(key) → [1] + 32 bytes.
      #
      # @param pubkey [String, nil] Base58 public key or nil.
      # @return [Array<Integer>]
      def self.encode_option_pubkey(pubkey)
        return [0] if pubkey.nil?

        [1] + Solace::Utils::Codecs.base58_to_bytes(pubkey)
      end

      # Encodes an Option<String> in Borsh format.
      # None → [0], Some(str) → [1] + u32 length + UTF-8 bytes.
      #
      # @param str [String, nil]
      # @return [Array<Integer>]
      def self.encode_option_string(str)
        return [0] if str.nil?

        bytes = str.encode('UTF-8').bytes
        [1] + encode_le_u32(bytes.length).bytes + bytes
      end

      # Encodes a Vec<SmartAccountSigner> in Borsh format.
      # u32 length prefix followed by each signer's 32-byte pubkey + 1-byte permission mask.
      #
      # @param signers [Array<SquadsSmartAccounts::SmartAccountSigner>]
      # @return [Array<Integer>]
      def self.encode_smart_account_signers(signers)
        encode_le_u32(signers.length).bytes +
          signers.flat_map do |signer|
            Solace::Utils::Codecs.base58_to_bytes(signer.pubkey) + [signer.permission]
          end
      end
    end
  end
end
