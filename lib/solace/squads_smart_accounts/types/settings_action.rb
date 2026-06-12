# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing one variant of the program's
    # SettingsAction Borsh enum — a single configuration change applied by a
    # settings transaction. Build instances via the variant factories.
    #
    # Borsh enums encode as a u8 variant index followed by the variant's fields;
    # the field bytes are encoded at construction and held in +data+.
    #
    # Supported variants (IDL order): AddSigner (0), RemoveSigner (1),
    # ChangeThreshold (2), SetTimeLock (3). The spending-limit and archival
    # variants are not yet implemented in this gem.
    #
    # @example Batch two changes atomically
    #   [
    #     SettingsAction.add_signer(pubkey: key, permission: Permissions::ALL),
    #     SettingsAction.change_threshold(2)
    #   ]
    SettingsAction = Data.define(
      :variant, # Integer — Borsh enum variant index
      :data     # Array<Integer> — encoded variant fields
    ) do
      # Builds an AddSigner action (variant 0).
      #
      # @param pubkey [#to_s] Pubkey of the signer to add.
      # @param permission [Integer] Bitmask built from Permissions constants.
      # @return [SettingsAction]
      def self.add_signer(pubkey:, permission:)
        new(variant: 0, data: Solace::Utils::Codecs.base58_to_bytes(pubkey.to_s) + [permission])
      end

      # Builds a RemoveSigner action (variant 1).
      #
      # @param pubkey [#to_s] Pubkey of the signer to remove.
      # @return [SettingsAction]
      def self.remove_signer(pubkey)
        new(variant: 1, data: Solace::Utils::Codecs.base58_to_bytes(pubkey.to_s))
      end

      # Builds a ChangeThreshold action (variant 2).
      #
      # @param threshold [Integer] The new approval threshold (u16).
      # @return [SettingsAction]
      def self.change_threshold(threshold)
        new(variant: 2, data: Solace::Utils::Codecs.encode_le_u16(threshold).bytes)
      end

      # Builds a SetTimeLock action (variant 3).
      #
      # @param seconds [Integer] Seconds between approval and execution (u32).
      # @return [SettingsAction]
      def self.set_time_lock(seconds)
        new(variant: 3, data: Solace::Utils::Codecs.encode_le_u32(seconds).bytes)
      end

      # Serializes the action in Borsh format: u8 variant index + field bytes.
      #
      # @return [Array<Integer>] The serialized action.
      def serialize
        [variant] + data
      end
    end
  end
end
