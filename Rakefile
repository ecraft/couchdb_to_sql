# frozen_string_literal: true

require 'bundler'
require 'rubygems'
require 'rake/testtask'
require 'rubocop/rake_task'

Bundler::GemHelper.install_tasks
RuboCop::RakeTask.new

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList.new('test/unit/**/*.rb')

  # Without this setting, the unit test running generates a load of warnings in unrelated/3rd party gems, which obscures the
  # real output of the test runs and makes it harder to read.
  t.warning = false
end

# The tests are unfortunately at the moment MRI only, because of an Sqlite dependency:
# https://github.com/ecraft/couchdb_to_sql/issues/9
if defined?(JRUBY_VERSION)
  desc 'Runs Rubocop linting'
  task default: :rubocop
else
  desc 'Run Rubocop linting and the unit tests'
  task default: %i[rubocop test]
end
