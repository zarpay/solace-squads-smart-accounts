# frozen_string_literal: true

require 'rake/testtask'
# Load custom rake task handlers.
Dir.glob('rake/handlers/**/*.rb').each { |task_file| load task_file }

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb', 'test/test_setup.rb']
  t.verbose = true
end

# Funds fixture accounts on the local test validator.
# Run once before the test suite when starting fresh: bundle exec rake bootstrap
Rake::TestTask.new(:bootstrap) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/bootstrap.rb']
  t.verbose = true
end

namespace :idl do
  desc 'Compare upstream IDL (GitHub) with local IDL'
  task :compare do
    Rake::Handlers::IDLCompare.run
  end
end

task default: :test
