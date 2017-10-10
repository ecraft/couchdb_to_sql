# frozen_string_literal: true

require 'couchdb_to_sql/table_operator'

module CouchdbToSql
  #
  # Table definition handler for handling database UPSERT operations.
  #
  class TableDeletedMarker < TableBuilder
    def execute
      dataset = handler.database[table_name]

      if attributes.key?(:id)
        handler.changes.log_info "Deletion with 'id' field present (#{primary_key} '#{handler.id}'), assuming tombstone. " \
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
      else
        handler.changes.log_info "Found deletion without 'id' field (#{primary_key} '#{handler.id}'), assuming plaque. Leaving " \
                                 'data as-is in SQL/Postgres, only setting _deleted* fields.'
        records_modified = dataset
          .where(key_filter)
          .update(
            _deleted: true,
            _deleted_timestamp: Sequel::CURRENT_TIMESTAMP,
            rev: handler.rev
          )

        handler.changes.log_info "#{records_modified} record(s) were marked as deleted"
      end
    end

    def key_filter
      {
        primary_key => handler.id
      }
    end
  end
end
