# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Immutable value object holding the full deterministic identity of a smart
    # account — everything a client needs to persist for indexing before (or
    # after) creating it on-chain.
    #
    # @example
    #   identity = program.next_smart_account
    #   identity.settings_seed         # => 1234 (pass to create_smart_account)
    #   identity.settings_address      # => base58 settings PDA
    #   identity.smart_account_address # => base58 default vault PDA (index 0)
    SmartAccountIdentity = Data.define(
      :settings_seed,        # Integer — seed the settings PDA is derived from
      :settings_address,     # String  — base58 address of the settings account
      :smart_account_address # String  — base58 address of the default vault (account index 0)
    )
  end
end
