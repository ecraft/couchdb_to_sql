# frozen_string_literal: true

require 'couchdb_to_sql/table_operator'

module CouchdbToSql
  #
  # Table definition handler which handles database INSERT operations.
  #
  class TableBuilder < TableOperator
    attr_reader :attributes
    attr_reader :data

    def initialize(parent, table_name, opts = {}, &block)
      @_collections = []

      @parent     = parent
      @data       = opts[:data] || parent.document
      @table_name = table_name.to_sym

      deduce_primary_key(opts)

      @attributes = {}
      set_primary_key_attribute
      set_attributes_from_data

      instance_eval(&block) if block_given?
    end

    def id
      handler.id
    end

    def document
      parent.document
    end
    alias doc document

    def database
      @database ||= handler.database
    end

    #### DSL Methods

    def column(*args)
      column = args.first
      field  = args.last

      if block_given?
        set_attribute(column, yield)
      elsif field.is_a?(Symbol)
        set_attribute(column, data[field.to_s])
      elsif args.length > 1
        set_attribute(column, field)
      end
    end

    #### Support Methods

    def execute
      # Insert the record and prepare ID for sub-tables
      id = dataset.insert(attributes)
      set_attribute(primary_key, id) unless id.blank?
    end

    private

    def schema
      handler.schema(table_name)
    end

    def dataset
      database[table_name]
    end

    # Set the primary key in the attributes so that the insert request will have all it requires.
    def set_primary_key_attribute
      base = {}
      base[primary_key] = id

      attributes.update(base)
    end

    # Take the document and try to automatically set the fields from the columns
    def set_attributes_from_data
      return unless data.is_a?(Hash) || data.is_a?(CouchRest::Document)

      data.each do |k, v|
        k = k.to_sym
        next if %i[_id _rev].include?(k)

        set_attribute(k, v) if schema.column_names.include?(k)
      end
    end

    def set_attribute(name, value)
      name   = name.to_sym
      column = schema.columns[name]
      return if column.nil?

      # Perform basic typecasting to avoid errors with empty fields in databases that do not support them.
      case column[:type]
      when :string
        value = value.nil? ? nil : value.to_s
      when :integer
        value = value.to_i
      when :float
        value = value.to_f
      else
        value = nil if value.to_s.empty?
      end
      attributes[name] = value
    end
  end
end
