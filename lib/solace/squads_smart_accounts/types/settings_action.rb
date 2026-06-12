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
    # ChangeThreshold (2), SetTimeLock (3), AddSpendingLimit (4),
    # RemoveSpendingLimit (5). SetArchivalAuthority (6) is not implemented —
    # the archival feature is unimplemented in the deployed program.
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
        new(variant: 0, data: Solace::Utils::Codecs.encode_pubkey(pubkey) + [permission])
      end

      # Builds a RemoveSigner action (variant 1).
      #
      # @param pubkey [#to_s] Pubkey of the signer to remove.
      # @return [SettingsAction]
      def self.remove_signer(pubkey)
        new(variant: 1, data: Solace::Utils::Codecs.encode_pubkey(pubkey))
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

      # Builds an AddSpendingLimit action (variant 4).
      #
      # @param seed [#to_s] Arbitrary pubkey seeding the SpendingLimit PDA.
      # @param account_index [Integer] Vault index the limit spends from.
      # @param mint [#to_s] Token mint; DEFAULT_PUBKEY for SOL.
      # @param amount [Integer] Amount spendable per period (mint decimals).
      # @param period [Integer] Period enum value (reset cadence).
      # @param signers [Array<#to_s>] Pubkeys allowed to use the limit.
      # @param destinations [Array<#to_s>] Allowed destinations; empty = any.
      # @param expiration [Integer] Unix expiration timestamp; I64_MAX = never.
      # @return [SettingsAction]
      def self.add_spending_limit(
        seed:,
        account_index:,
        mint:,
        amount:,
        period:,
        signers:,
        destinations:,
        expiration:
      )
        new(
          variant: 4,
          data:    Solace::Utils::Codecs.encode_pubkey(seed) +
                   [account_index] +
                   Solace::Utils::Codecs.encode_pubkey(mint) +
                   Solace::Utils::Codecs.encode_le_u64(amount).bytes +
                   [period] +
                   Solace::Utils::Codecs.encode_vec_pubkeys(signers) +
                   Solace::Utils::Codecs.encode_vec_pubkeys(destinations) +
                   Solace::Utils::Codecs.encode_le_i64(expiration).bytes
        )
      end

      # Builds a RemoveSpendingLimit action (variant 5).
      #
      # @param spending_limit [#to_s] Address of the SpendingLimit PDA to remove.
      # @return [SettingsAction]
      def self.remove_spending_limit(spending_limit)
        new(variant: 5, data: Solace::Utils::Codecs.encode_pubkey(spending_limit))
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
