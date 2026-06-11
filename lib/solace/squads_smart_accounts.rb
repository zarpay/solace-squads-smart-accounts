# frozen_string_literal: true

require 'solace'
require 'solace/squads_smart_accounts/version'
require 'solace/squads_smart_accounts/constants'
require 'solace/squads_smart_accounts/codecs_extensions'

# Load types
Dir[File.join(__dir__, 'squads_smart_accounts/types/*.rb')].each { |f| require f }

# Load instructions and composers
Dir[File.join(__dir__, 'squads_smart_accounts/instructions/*.rb')].each { |f| require f }
Dir[File.join(__dir__, 'squads_smart_accounts/composers/*.rb')].each { |f| require f }

# Load programs
Dir[File.join(__dir__, 'squads_smart_accounts/programs/*.rb')].each { |f| require f }

module Solace
  module SquadsSmartAccounts
    class Error < StandardError; end
  end
end
