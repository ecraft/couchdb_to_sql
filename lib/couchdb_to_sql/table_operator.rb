# frozen_string_literal: true

module CouchdbToSql
  #
  # Abstract base class for classes which performs table operations (build, destroy, upsert, etc.)
  #
  class TableOperator
    # @return [DocumentHandler]
    attr_reader :parent

    # @return [String]
    attr_reader :table_name

    # @return [Symbol]
    attr_reader :primary_key

    def initialize(parent, table_name, opts = {})
      @parent = parent
      @table_name = table_name

      deduce_primary_key(opts)
    end

    def deduce_primary_key(opts)
      @primary_key = (opts[:primary_key] || "#{@table_name.to_s.singularize}_id").to_sym
    end

    def handler
      parent.handler
    end

    def execute
      raise NotImplementedError, "Classes deriving from #{self} must implement the 'execute' method."
    end
  end
end
