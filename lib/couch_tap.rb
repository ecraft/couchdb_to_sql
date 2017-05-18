# Low level requirements
require 'active_support/core_ext/object/blank'
require 'active_support/inflector'
require 'couchrest'
require 'httpclient'
require 'json'
require 'logging_library'
require 'sequel'

# Our stuff
require 'couch_tap/changes'
require 'couch_tap/schema'
require 'couch_tap/document_handler'
require 'couch_tap/builders/collection'
require 'couch_tap/builders/table'
require 'couch_tap/destroyers/collection'
require 'couch_tap/destroyers/table'

module CouchTap
  Error = Class.new(StandardError)
  InvalidDataError = Class.new(Error)

  extend LoggingLibrary::Loggable

  extend self

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
