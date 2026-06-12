# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object representing a signer entry on a smart account.
    #
    # @example
    #   SmartAccountSigner.new(
    #     pubkey:     '7xKX...',
    #     permission: Permissions::ALL
    #   )
    SmartAccountSigner = Data.define(
      :pubkey,     # String  — base58 public key of the signer
      :permission  # Integer — bitmask built from Permissions constants
    ) do
      # Normalizes the pubkey to its base58 string so callers can pass a
      # String, Keypair, or PublicKey interchangeably.
      #
      # @param pubkey [#to_s] The signer's public key in any representation.
      # @param permission [Integer] Bitmask built from Permissions constants.
      def initialize(pubkey:, permission:)
        super(pubkey: pubkey.to_s, permission:)
      end
    end
  end
end
