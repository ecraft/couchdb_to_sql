# frozen_string_literal: true

# Low level requirements
require 'active_support/core_ext/object/blank'
require 'active_support/inflector'
require 'couchrest'
require 'httpclient'
require 'json'
require 'logging_library'
require 'set'
require 'sequel'

# Our stuff
require 'couchdb_to_sql/changes'
require 'couchdb_to_sql/schema'
require 'couchdb_to_sql/document_handler'
require 'couchdb_to_sql/builders/collection'
require 'couchdb_to_sql/builders/table'
require 'couchdb_to_sql/destroyers/collection'
require 'couchdb_to_sql/destroyers/table'

module CouchdbToSql
  extend LoggingLibrary::Loggable

  Error = Class.new(StandardError)
  InvalidDataError = Class.new(Error)

  COUCHDB_TO_SQL_SEQUENCES_TABLE = :_couchdb_to_sql_sequences

  module_function

  def changes(database, &block)
    (@changes ||= []) << Changes.new(database, &block)
  end

  def start
    threads = []
    @changes.each do |changes|
      threads << Thread.new(changes, &:start)
    end
    threads.each(&:join)
  end
end
