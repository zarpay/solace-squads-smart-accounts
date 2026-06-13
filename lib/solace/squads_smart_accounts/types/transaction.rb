# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object for a deserialized Transaction account — a pending
    # vault transaction stored by `createTransaction` and replayed by
    # `executeTransaction`.
    #
    # Layout follows the deployed (newer) program, which the bundled IDL does not
    # describe: the account holds a `Payload` enum after `index`, whose
    # TransactionPayload variant carries account_index, ephemeral_signer_bumps,
    # and the message. The stored message (SmartAccountTransactionMessage) uses
    # standard Borsh Vec (u32 counts) — distinct from the SmallVec format used to
    # *submit* the message. Only the message header counts and account_keys are
    # decoded (enough to verify a round-trip); compiled instructions and
    # address-table lookups are skipped.
    Transaction = Data.define(
      :settings,                 # String  — base58 consensus (settings) account
      :creator,                  # String  — base58 creator
      :rent_collector,           # String  — base58 rent collector
      :index,                    # Integer — transaction index (u64)
      :account_index,            # Integer — vault index the message spends from
      :num_signers,              # Integer — message: total signer keys
      :num_writable_signers,     # Integer — message: writable signers
      :num_writable_non_signers, # Integer — message: writable non-signers
      :account_keys              # Array<String> — message: base58 keys in canonical order
    ) do
      # The stored message's account_keys as ordered account metas — the inverse
      # of how AccountContext#compile lays them out. Each meta carries the same
      # {signer:, writable:} flags vocabulary AccountContext uses, derived from
      # the canonical ordering [writable signers, readonly signers, writable
      # non-signers, readonly non-signers]. This is the input executeTransaction
      # replays as its remaining accounts (the lone signer being the vault PDA).
      #
      # @return [Array<Hash>] Each { pubkey: String, signer: Boolean, writable: Boolean }.
      def account_metas
        account_keys.each_index.map do |index|
          {
            pubkey:   account_keys[index],
            signer:   index < num_signers,
            writable: writable_index?(index)
          }
        end
      end

      private

      # Whether the account at the given canonical index is writable: writable
      # signers occupy the leading positions, writable non-signers immediately
      # follow the signer block.
      #
      # @param index [Integer] Position in account_keys.
      # @return [Boolean]
      def writable_index?(index)
        index < num_writable_signers ||
          (index >= num_signers && index < num_signers + num_writable_non_signers)
      end

      class << self
        # Deserializes a Transaction account from a stream of Borsh-encoded account data.
        #
        # @param io [IO, StringIO] Stream positioned at the start of the account data.
        # @return [Transaction] The deserialized, frozen value.
        # @raise [RuntimeError] If the payload is not a TransactionPayload.
        def deserialize(io)
          io.read(8) # skip 8-byte Anchor discriminator

          settings       = Solace::Utils::Codecs.decode_pubkey(io)
          creator        = Solace::Utils::Codecs.decode_pubkey(io)
          rent_collector = Solace::Utils::Codecs.decode_pubkey(io)
          index          = Solace::Utils::Codecs.decode_le_u64(io)

          enforce_known_variant!(io)

          account_index = Solace::Utils::Codecs.decode_u8(io)

          # ephemeral_signer_bumps: Borsh Vec<u8> (u32 length + raw bytes). Skipped.
          io.read(Solace::Utils::Codecs.decode_le_u32(io))

          # Embedded SmartAccountTransactionMessage header + account_keys (Vec, u32 count).
          num_signers              = Solace::Utils::Codecs.decode_u8(io)
          num_writable_signers     = Solace::Utils::Codecs.decode_u8(io)
          num_writable_non_signers = Solace::Utils::Codecs.decode_u8(io)
          account_keys             = Solace::Utils::Codecs.decode_vec_pubkeys(io)

          new(
            settings:,
            creator:,
            rent_collector:,
            index:,
            account_index:,
            num_signers:,
            num_writable_signers:,
            num_writable_non_signers:,
            account_keys:
          )
        end

        private

        # Reads and validates the Payload enum variant byte. Variant 0 is
        # Payload::TransactionPayload — the only variant this gem supports.
        #
        # @param io [IO, StringIO] The stream to read from.
        # @raise [RuntimeError] If the variant is not TransactionPayload.
        def enforce_known_variant!(io)
          variant = Solace::Utils::Codecs.decode_u8(io)
          return if variant.zero?

          raise "Unsupported transaction payload variant: #{variant}"
        end
      end
    end
  end
end
