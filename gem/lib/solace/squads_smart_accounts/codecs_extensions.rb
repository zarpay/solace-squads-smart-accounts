# frozen_string_literal: true

module Solace
  module Utils
    # Extensions to Solace::Utils::Codecs for Anchor programs and Borsh types not
    # covered by the base gem. Candidates for upstreaming to solace when the need
    # is confirmed across other extension gems.
    module Codecs
      extend self

      # Encodes a SmallVec<u8, u8>: u8 length prefix + raw bytes.
      #
      # @param bytes [Array<Integer>] The raw bytes (max 255).
      # @return [Array<Integer>]
      def encode_smallvec_u8_bytes(bytes)
        [bytes.length] + bytes
      end

      # Encodes a u16 as 2 little-endian bytes.
      #
      # @param u16 [Integer] Value in range 0..65535.
      # @return [String] 2-byte little-endian binary string.
      def encode_le_u16(u16)
        [u16].pack('S<')
      end

      # Encodes a SmallVec<u16, u8>: u16 LE length prefix + raw bytes.
      #
      # @param bytes [Array<Integer>] The raw bytes (max 65535).
      # @return [Array<Integer>]
      def encode_smallvec_u16_bytes(bytes)
        encode_le_u16(bytes.length).bytes + bytes
      end

      # Encodes a u32 as 4 little-endian bytes.
      #
      # @param u32 [Integer] Value in range 0..4294967295.
      # @return [String] 4-byte little-endian binary string.
      def encode_le_u32(u32)
        [u32].pack('L<')
      end

      # Encodes an i64 as 8 little-endian bytes (two's complement).
      #
      # @param i64 [Integer] Value in range -2**63..2**63-1.
      # @return [String] 8-byte little-endian binary string.
      def encode_le_i64(i64)
        [i64].pack('q<')
      end

      # Encodes a Borsh bool as a single byte: false → 0, true → 1.
      #
      # @param bool [Boolean] The value to encode.
      # @return [Array<Integer>] A single-element byte array.
      def encode_bool(bool)
        [bool ? 1 : 0]
      end

      # Encodes a u128 as 16 little-endian bytes (two u64 words, low word first).
      #
      # @param u128 [Integer] Value in range 0..2**128-1.
      # @return [String] 16-byte little-endian binary string.
      def encode_le_u128(u128)
        [u128 & 0xFFFFFFFFFFFFFFFF, u128 >> 64].pack('Q<Q<')
      end

      # Encodes a Borsh bytes field: u32 LE length prefix + raw bytes.
      #
      # @param bytes [Array<Integer>] The raw bytes.
      # @return [Array<Integer>]
      def encode_bytes(bytes)
        encode_le_u32(bytes.length).bytes + bytes
      end

      # Encodes an Option<String> in Borsh format.
      # None → [0], Some(str) → [1] + u32 length + UTF-8 bytes.
      #
      # @param str [String, nil]
      # @return [Array<Integer>]
      def encode_option_string(str)
        return [0] if str.nil?

        bytes = str.encode('UTF-8').bytes
        [1] + encode_le_u32(bytes.length).bytes + bytes
      end

      # Encodes a public key as 32 bytes. Accepts any representation that
      # resolves to a base58 string via #to_s (String, Keypair, PublicKey).
      #
      # @param pubkey [#to_s] The public key in any representation.
      # @return [Array<Integer>] 32 bytes.
      def encode_pubkey(pubkey)
        Solace::Utils::Codecs.base58_to_bytes(pubkey.to_s)
      end

      # Encodes an Option<publicKey> in Borsh format.
      # None → [0], Some(key) → [1] + 32 bytes.
      #
      # @param pubkey [String, nil] Base58 public key or nil.
      # @return [Array<Integer>]
      def encode_option_pubkey(pubkey)
        return [0] if pubkey.nil?

        [1] + encode_pubkey(pubkey)
      end

      # Encodes a Vec<publicKey> in Borsh format.
      # u32 LE count prefix followed by each 32-byte pubkey.
      #
      # @param pubkeys [Array<#to_s>] The public keys in any representation.
      # @return [Array<Integer>]
      def encode_vec_pubkeys(pubkeys)
        encode_le_u32(pubkeys.length).bytes +
          pubkeys.flat_map { |pubkey| encode_pubkey(pubkey) }
      end

      # Encodes a SmallVec<u8, Pubkey>: u8 count prefix followed by each 32-byte
      # pubkey. Used by the transaction message header's account_keys (distinct
      # from encode_vec_pubkeys, which uses a u32 count).
      #
      # @param pubkeys [Array<#to_s>] The public keys in any representation (max 255).
      # @return [Array<Integer>]
      def encode_smallvec_u8_pubkeys(pubkeys)
        [pubkeys.length] + pubkeys.flat_map { |pubkey| encode_pubkey(pubkey) }
      end

      # Encodes a Vec<SmartAccountSigner> in Borsh format.
      # u32 length prefix followed by each signer's 32-byte pubkey + 1-byte permission mask.
      #
      # @param signers [Array<SquadsSmartAccounts::SmartAccountSigner>]
      # @return [Array<Integer>]
      def encode_smart_account_signers(signers)
        encode_le_u32(signers.length).bytes +
          signers.flat_map do |signer|
            encode_pubkey(signer.pubkey) + [signer.permission]
          end
      end

      # Encodes a Vec<SettingsAction> in Borsh format.
      # u32 LE count prefix followed by each action's variant index + field bytes.
      #
      # @param actions [Array<SquadsSmartAccounts::SettingsAction>]
      # @return [Array<Integer>]
      def encode_settings_actions(actions)
        encode_le_u32(actions.length).bytes + actions.flat_map(&:serialize)
      end

      # Encodes a SmallVec<u8, CompiledInstruction> — the wire format the Squads
      # program expects for synchronously executed inner instructions.
      #
      # NOTE: this intentionally does NOT reuse Solace's InstructionSerializer.
      # That serializer produces the Solana transaction wire format, which uses
      # compact-u16 (varint) length prefixes for the vec count, account indexes,
      # and data. The Squads SmallVec format uses fixed-width prefixes instead:
      # u8 for the vec count, u8 for the account indexes length, and u16 LE for
      # the data length. The two encodings coincide for lengths < 128 (compact-u16
      # encodes those as a single byte) but diverge beyond that, so reusing the
      # Solana format would corrupt larger instructions silently.
      #
      # Each instruction is a {Solace::Instruction} whose program_index and
      # accounts are indexes into the full remaining-accounts list (signers included).
      # Layout per instruction: u8 program_id_index + SmallVec<u8,u8> account
      # indexes + SmallVec<u16,u8> data.
      #
      # @param instructions [Array<Solace::Instruction>]
      # @return [Array<Integer>]
      def encode_compiled_instructions(instructions)
        [instructions.length] +
          instructions.flat_map do |ix|
            [ix.program_index] +
              encode_smallvec_u8_bytes(ix.accounts) +
              encode_smallvec_u16_bytes(ix.data)
          end
      end

      # Decodes an i64 from 8 little-endian bytes (two's complement).
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Integer] Value in range -2**63..2**63-1.
      def decode_le_i64(stream)
        stream.read(8).unpack1('q<')
      end

      # Decodes a Vec<publicKey> in Borsh format.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Array<String>] Base58 public keys.
      def decode_vec_pubkeys(stream)
        Array.new(decode_le_u32(stream)) { decode_pubkey(stream) }
      end

      # Decodes a Borsh bytes / Vec<u8> field: u32 LE length prefix + raw bytes.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [String] The raw bytes as a binary string.
      def decode_bytes(stream)
        stream.read(decode_le_u32(stream))
      end

      # Decodes a u8 from 1 byte.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Integer] Value in range 0..255.
      def decode_u8(stream)
        stream.read(1).unpack1('C')
      end

      # Decodes a u16 from 2 little-endian bytes.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Integer] Value in range 0..65535.
      def decode_le_u16(stream)
        stream.read(2).unpack1('S<')
      end

      # Decodes a u32 from 4 little-endian bytes.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Integer] Value in range 0..4294967295.
      def decode_le_u32(stream)
        stream.read(4).unpack1('L<')
      end

      # Decodes a u128 from 16 little-endian bytes (two u64 words, low word first).
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Integer] Value in range 0..2**128-1.
      def decode_le_u128(stream)
        lo, hi = stream.read(16).unpack('Q<Q<')
        lo + (hi << 64)
      end

      # Decodes a public key from 32 bytes.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [String] Base58 public key.
      def decode_pubkey(stream)
        Solace::Utils::Codecs.bytes_to_base58(stream.read(32).bytes)
      end

      # Decodes an Option<publicKey> in Borsh format.
      # None → nil, Some(key) → base58 pubkey.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [String, nil] Base58 public key or nil.
      def decode_option_pubkey(stream)
        return nil if decode_u8(stream).zero?

        decode_pubkey(stream)
      end

      # Decodes a Vec<SmartAccountSigner> in Borsh format.
      # u32 length prefix followed by each signer's 32-byte pubkey + 1-byte permission mask.
      #
      # @param stream [IO, StringIO] The stream to read from.
      # @return [Array<SquadsSmartAccounts::SmartAccountSigner>]
      def decode_smart_account_signers(stream)
        Array.new(decode_le_u32(stream)) do
          SquadsSmartAccounts::SmartAccountSigner.new(
            pubkey:     decode_pubkey(stream),
            permission: decode_u8(stream)
          )
        end
      end
    end
  end
end
