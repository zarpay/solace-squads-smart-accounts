# frozen_string_literal: true

require 'rake/testtask'
# Load custom rake task handlers.
Dir.glob('rake/handlers/**/*.rb').each { |task_file| load task_file }

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.test_files = FileList['test/**/*_test.rb', 'test/test_setup.rb']
  t.verbose    = true
end

namespace :idl do
  desc 'Compare upstream IDL (GitHub) with local IDL'
  task :compare do
    Rake::Handlers::IDLCompare.run
  end
end

task default: :test
