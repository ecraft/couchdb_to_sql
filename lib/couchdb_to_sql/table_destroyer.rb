# frozen_string_literal: true

require 'couchdb_to_sql/table_operator'

module CouchdbToSql
  #
  # The table destroyer will go through a table definition and make sure that
  # all rows that belong to the document's id are deleted from the system.
  #
  class TableDestroyer < TableOperator
    def execute
      dataset = handler.database[table_name]
      dataset.where(key_filter).delete
    end

    def key_filter
      {
        primary_key => handler.id
      }
    end
  end
end
