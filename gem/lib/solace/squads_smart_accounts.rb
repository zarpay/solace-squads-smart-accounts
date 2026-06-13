# frozen_string_literal: true

require 'solace'
require 'solace/squads_smart_accounts/version'
require 'solace/squads_smart_accounts/constants'
require 'solace/squads_smart_accounts/codecs_extensions'

def req_glob(path)
  Dir[File.join(__dir__, path)].each { |f| require f }
end

# Load types
req_glob('squads_smart_accounts/types/*.rb')

# Load instructions and composers
req_glob('squads_smart_accounts/instructions/*.rb')
req_glob('squads_smart_accounts/composers/*.rb')

# Load programs
req_glob('squads_smart_accounts/programs/*.rb')

# Load the reverse vault-address lookup (depends on the program layer)
require 'solace/squads_smart_accounts/vault_index'

module Solace
  module SquadsSmartAccounts
    class Error < StandardError; end
  end
end
