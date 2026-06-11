# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Bitmask constants for the three signer permission bits on a smart account.
    # Permissions are combined with bitwise OR to grant multiple roles.
    #
    # @example Grant all permissions
    #   Permissions::ALL
    #
    # @example Grant initiate and vote only
    #   Permissions::INITIATE | Permissions::VOTE
    module Permissions
      # Permission to initiate (create) new transactions.
      INITIATE = 0b001

      # Permission to vote (approve or reject) on proposals.
      VOTE     = 0b010

      # Permission to execute approved transactions.
      EXECUTE  = 0b100

      # Convenience constant granting all three permissions.
      ALL      = INITIATE | VOTE | EXECUTE
    end
  end
end
