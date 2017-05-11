require 'bundler'
require 'rubygems'
require 'rake/testtask'
require 'rubocop/rake_task'

Bundler::GemHelper.install_tasks
RuboCop::RakeTask.new

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList.new('test/unit/**/*.rb')
end

# TODO: Reenable tests here: https://github.com/ecraft/couch_tap/issues/5
desc 'Run Rubocop linting'
task default: :rubocop
