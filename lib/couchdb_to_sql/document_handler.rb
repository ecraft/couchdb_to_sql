# frozen_string_literal: true

module CouchdbToSql
  #
  # Handles document insertion, deletion and 'marking as deleted' operations.
  #
  # This class delegates the actual insertion, deletion etc to the various `Table*` classes.
  #
  class DocumentHandler
    attr_reader :changes, :filter, :mode
    attr_accessor :document

    def initialize(changes, filter = {}, &block)
      @changes  = changes
      @filter   = filter
      @_block   = block
      @mode     = nil
    end

    def handles?(doc)
      @filter.each do |k, v|
        return false if doc[k.to_s] != v
      end
      true
    end

    ### START DSL

    # Handle a table definition.
    def table(name, opts = {}, &block)
      if @mode == :delete
        TableDestroyer.new(self, name, opts).execute
      elsif @mode == :mark_as_deleted
        TableDeletedMarker.new(self, name, opts).execute
      elsif @mode == :insert
        TableBuilder.new(self, name, opts, &block).execute
      end
    end

    ### END DSL

    def handler
      self
    end

    def primary_keys
      []
    end

    def key_filter
      {}
    end

    def id
      document['_id']
    end

    def rev
      document['_rev']
    end

    def insert(document)
      @mode = :insert
      self.document = document
      instance_eval(&@_block)
    end

    def delete(document)
      @mode = :delete
      self.document = document
      instance_eval(&@_block)
    end

    def mark_as_deleted(document)
      @mode = :mark_as_deleted
      self.document = document
      instance_eval(&@_block)
    end

    def schema(name)
      changes.schema(name)
    end

    def database
      changes.database
    end
  end
end
