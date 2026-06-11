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
    )
  end
end
