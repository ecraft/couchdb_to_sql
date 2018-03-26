# frozen_string_literal: true

require 'couchdb_to_sql/table_operator'

module CouchdbToSql
  #
  # Table definition handler for handling database UPSERT operations.
  #
  class TableDeletedMarker < TableBuilder
    def execute
      dataset = handler.database[table_name]
      if doc['_plaque']
        records_modified = dataset
          .where(key_filter)
          .update(
            _deleted: true,
            _deleted_timestamp: Sequel::CURRENT_TIMESTAMP,
            rev: handler.rev
          )
        return if records_modified == 0
        handler.changes.log_info "#{table_name}: #{records_modified} record(s) were marked as deleted"
      else
        handler.changes.log_info "Deletion with additional info present (#{primary_key} '#{handler.id}'), assuming tombstone. " \
                                 'Updating data in SQL/Postgres database with data from CouchDB document.'
        fields = attributes.merge(
          _deleted: true,
          _deleted_timestamp: Sequel::CURRENT_TIMESTAMP,
          rev: handler.rev
        )

        dataset
          .insert_conflict(
            target: primary_key,
            update: fields
          )
          .insert(fields)
      end
    end

    def key_filter
      {
        primary_key => handler.id
      }
    end
  end
end
