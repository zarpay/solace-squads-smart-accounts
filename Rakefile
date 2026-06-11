# frozen_string_literal: true

require 'rake/testtask'
require 'json'
require 'open3'

# Load custom rake tasks from rake/handlers/
Dir.glob('rake/handlers/**/*.rb').each { |task_file| load task_file }

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb', 'test/test_setup.rb']
  t.verbose = true
end

namespace :idl do
  desc 'Compare onchain IDL with local IDL. Usage: rake idl:compare[mainnet]'
  task :compare, [:cluster] do |_t, args|
    cluster = args[:cluster] || 'mainnet'

    Rake::Handlers::IDLCompare.run(cluster)
  end
end

task default: :test
