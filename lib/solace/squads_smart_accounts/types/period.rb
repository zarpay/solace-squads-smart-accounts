# frozen_string_literal: true

module Solace
  module SquadsSmartAccounts
    # Borsh enum values for a spending limit's reset period. When the period
    # passes, the remaining amount resets — except ONE_TIME, which never resets.
    #
    # @example A daily allowance
    #   Period::DAY
    module Period
      # The limit never resets — once spent, it is exhausted.
      ONE_TIME = 0

      # The remaining amount resets every day.
      DAY      = 1

      # The remaining amount resets every week.
      WEEK     = 2

      # The remaining amount resets every month.
      MONTH    = 3
    end
  end
end
