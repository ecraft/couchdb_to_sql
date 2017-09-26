# frozen_string_literal: true

source 'https://rubygems.org'
gemspec

if defined?(JRUBY_VERSION)
  gem 'jdbc-postgres'
else
  gem 'pg'
  gem 'sqlite3'
end
