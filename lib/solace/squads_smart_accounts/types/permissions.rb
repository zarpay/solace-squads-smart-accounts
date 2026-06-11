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
    #
    # @example Build a mask from permission names
    #   Permissions.mask(:initiate, :vote)
    module Permissions
      # Permission to initiate (create) new transactions.
      INITIATE = 0b001

      # Permission to vote (approve or reject) on proposals.
      VOTE     = 0b010

      # Permission to execute approved transactions.
      EXECUTE  = 0b100

      # Convenience constant granting all three permissions.
      ALL      = INITIATE | VOTE | EXECUTE

      # Builds a permission bitmask from named permissions.
      #
      # @param names [Array<Symbol>] Any of :initiate, :vote, :execute, :all.
      # @return [Integer] Combined permission bitmask.
      # @raise [ArgumentError] If a name doesn't correspond to a permission.
      def self.mask(*names)
        names.reduce(0) do |mask, name|
          raise ArgumentError, "unknown permission: #{name.inspect}" unless const_defined?(name.to_s.upcase)

          mask | const_get(name.to_s.upcase)
        end
      end
    end
  end
end
