
# frozen_string_literal: true

module CouchdbToSql
  module Destroyers
    #
    # The table destroyer will go through a table definition and make sure that
    # all rows that belong to the document's id are deleted from the system.
    #
    # It'll automatically go through each collection definition and recursively
    # ensure that everything has been cleaned up.
    #
    class Table
      attr_reader :parent, :name, :primary_keys

      def initialize(parent, name, opts = {}, &block)
        @_collections = []

        @parent = parent
        @name   = name

        @primary_keys = parent.primary_keys.dup

        # As we're deleting, only assign the primary key for the first table
        if @primary_keys.empty?
          @primary_keys << (opts[:primary_key] || "#{@name.to_s.singularize}_id").to_sym
        end

        instance_eval(&block) if block_given?
      end

      def execute
        dataset = handler.database[name]
        dataset.where(key_filter).delete
        @_collections.each(&:execute)
      end

      def handler
        parent.handler
      end

      # Unlike building new rows, delete only requires the main primary key to be available.
      def key_filter
        {
          @primary_keys.first => handler.id
        }
      end

      ### DSL methods

      def collection(_field, opts = {}, &block)
        @_collections << Collection.new(self, opts, &block)
      end

      ### Dummy helper methods

      def column(*_args)
        nil
      end

      def document
        {}
      end
      alias doc document

      def data
        {}
      end
    end
  end
end
