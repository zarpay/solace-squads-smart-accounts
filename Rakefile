# frozen_string_literal: true

require 'rake/testtask'
require 'json'
require 'open3'
require_relative 'lib/solace/squads_smart_accounts/constants'

# Load custom rake task handlers.
Dir.glob('rake/handlers/**/*.rb').each { |task_file| load task_file }

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb', 'test/test_setup.rb']
  t.verbose = true
end

namespace :idl do
  desc 'Compare onchain IDL with local IDL. Usage: rake idl:compare[mainnet|devnet]'
  task :compare, [:cluster] do |_t, args|
    # Default to mainnet when no cluster argument is provided.
    cluster = args[:cluster] || 'mainnet'

    # Select the program ID that matches the target cluster.
    program_id = case cluster
                 when 'devnet' then Solace::SquadsSmartAccounts::DEVNET_PROGRAM_ID
                 else               Solace::SquadsSmartAccounts::MAINNET_PROGRAM_ID
                 end

    Rake::Handlers::IDLCompare.run(cluster, program_id)
  end
end

task default: :test
