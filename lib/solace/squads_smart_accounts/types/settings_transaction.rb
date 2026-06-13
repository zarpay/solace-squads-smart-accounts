# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object for a deserialized SettingsTransaction account — a
    # pending batch of SettingsActions stored by `createSettingsTransaction` and
    # applied by `executeSettingsTransaction` once its proposal is approved.
    #
    # Layout (state/settings_transaction.rs): settings(32), creator(32),
    # rent_collector(32), index(u64), bump(u8), actions(Vec<SettingsAction>).
    # Only the fixed header is decoded — enough to resolve the rent collector for
    # `closeSettingsTransaction` and verify identity; the trailing actions Vec is
    # not read (the program reads the actions on-chain).
    SettingsTransaction = Data.define(
      :settings,       # String  — base58 settings account this belongs to
      :creator,        # String  — base58 creator (a settings signer)
      :rent_collector, # String  — base58 rent collector (the create-time rent payer)
      :index,          # Integer — transaction index (u64)
      :bump            # Integer — transaction PDA bump seed
    ) do
      # Deserializes a SettingsTransaction account from a stream of Borsh-encoded
      # account data.
      #
      # @param io [IO, StringIO] Stream positioned at the start of the account data.
      # @return [SettingsTransaction] The deserialized, frozen value.
      def self.deserialize(io)
        io.read(8) # skip 8-byte Anchor discriminator

        new(
          settings:       Solace::Utils::Codecs.decode_pubkey(io),
          creator:        Solace::Utils::Codecs.decode_pubkey(io),
          rent_collector: Solace::Utils::Codecs.decode_pubkey(io),
          index:          Solace::Utils::Codecs.decode_le_u64(io),
          bump:           Solace::Utils::Codecs.decode_u8(io)
          # Trailing actions Vec<SettingsAction> is not read.
        )
      end
    end
  end
end
