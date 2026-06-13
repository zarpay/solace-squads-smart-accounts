# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing the deserialized Settings account of a
    # smart account. The settings account is the root state account created by
    # `createSmartAccount` and holds the signer set, threshold, and time lock.
    #
    # @example
    #   settings = program.get_settings(settings_address: settings_address)
    #   settings.threshold      # => 1
    #   settings.signers        # => [SmartAccountSigner, ...]
    Settings = Data.define(
      :seed,                    # Integer — index seed the settings PDA was derived from
      :settings_authority,      # String  — base58 pubkey; Pubkey::default() for autonomous accounts
      :threshold,               # Integer — signatures required to execute a transaction
      :time_lock,               # Integer — seconds between voting settlement and execution
      :transaction_index,       # Integer — last transaction index (0 = none created)
      :stale_transaction_index, # Integer — transactions up to this index are stale
      :archival_authority,      # String, nil — reserved for the archival feature
      :archivable_after,        # Integer — reserved for the archival feature
      :bump,                    # Integer — settings PDA bump seed
      :signers,                 # Array<SmartAccountSigner> — sorted by pubkey on-chain
      :account_utilization      # Integer — number of sub accounts in use
    ) do
      # Deserializes a Settings account from a stream of Borsh-encoded account data.
      #
      # @param io [IO, StringIO] Stream positioned at the start of the account data.
      # @return [Settings] The deserialized, frozen settings value.
      def self.deserialize(io)
        io.read(8) # skip 8-byte Anchor discriminator

        new(
          seed:                    Solace::Utils::Codecs.decode_le_u128(io),
          settings_authority:      Solace::Utils::Codecs.decode_pubkey(io),
          threshold:               Solace::Utils::Codecs.decode_le_u16(io),
          time_lock:               Solace::Utils::Codecs.decode_le_u32(io),
          transaction_index:       Solace::Utils::Codecs.decode_le_u64(io),
          stale_transaction_index: Solace::Utils::Codecs.decode_le_u64(io),
          archival_authority:      Solace::Utils::Codecs.decode_option_pubkey(io),
          archivable_after:        Solace::Utils::Codecs.decode_le_u64(io),
          bump:                    Solace::Utils::Codecs.decode_u8(io),
          signers:                 Solace::Utils::Codecs.decode_smart_account_signers(io),
          account_utilization:     Solace::Utils::Codecs.decode_u8(io)
          # Trailing reserved1/reserved2 bytes are not read.
        )
      end
    end
  end
end
