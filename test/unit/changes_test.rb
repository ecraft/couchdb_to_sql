# frozen_string_literal: true

require 'test_helper'

class ChangesTest < Test::Unit::TestCase
  def setup
    reset_test_couchdb!
    reset_test_sql_db!(sql_connection_string)
    build_sample_config
  end

  def test_basic_init
    @database = @changes.database
    assert @changes.database, 'Did not assign a database'
    assert @changes.database.is_a?(Sequel::Database)
    row = @database[CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE].first
    assert row, "Did not create a #{CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE} table"
    assert_equal row.fetch(:highest_sequence), '0', 'Did not set a default sequence number'
    assert_equal row.fetch(:couchdb_database_name), TEST_COUCHDB_NAME
  end

  def test_defining_document_handler
    assert_equal @changes.handlers.length, 3
    handler = @changes.handlers.first
    assert handler.is_a?(CouchdbToSql::DocumentHandler)
    assert_equal handler.filter, type: 'Foo'
  end

  def test_inserting_rows
    doc = {
      '_id' => '1234',
      'type' => 'Foo',
      'name' => 'Some Document'
    }
    row = {
      'seq' => 1,
      'id' => '1234',
      'doc' => doc
    }

    handler = @changes.handlers.first
    handler.expects(:delete).with(doc)
    handler.expects(:insert).with(doc)

    @changes.send(:process_row, row)

    # Should update seq
    assert_equal @changes.database[CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE].first[:highest_sequence], '1'
  end

  def test_inserting_rows_with_multiple_filters
    row = {
      'seq' => 3,
      'id' => '1234',
      'doc' => {
        'type' => 'Bar',
        'special' => true,
        'name' => 'Some Document'
      }
    }

    handler = @changes.handlers[0]
    handler.expects(:insert).never

    handler = @changes.handlers[1]
    handler.expects(:delete)
    handler.expects(:insert)

    handler = @changes.handlers[2]
    handler.expects(:delete)
    handler.expects(:insert)

    @changes.send(:process_row, row)
    assert_equal @changes.database[CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE].first.fetch(:highest_sequence), '3'
  end

  def test_mark_deleted_rows
    doc = {
      'order_number' => '12345',
      'customer_number' => '54321',
      'type' => 'Foo'
    }
    row = {
      'seq' => 9,
      'id' => '1234',
      'deleted' => true,
      'doc' => doc
    }

    handler = @changes.handlers[0]
    handler.expects(:mark_as_deleted).with(doc)

    handler = @changes.handlers[1]
    handler.expects(:delete).never
    handler.expects(:insert).never
    handler.expects(:mark_as_deleted).with(doc).never

    handler = @changes.handlers[2]
    handler.expects(:delete).never
    handler.expects(:insert).never
    handler.expects(:mark_as_deleted).with(doc).never

    @changes.send(:process_row, row)

    assert_equal @changes.database[CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE].first.fetch(:highest_sequence), '9'
  end

  def test_deleting_rows
    doc = {
      'order_number' => '12345',
      'customer_number' => '54321'
    }
    row = {
      'seq' => 9,
      'id' => '1234',
      'deleted' => true,
      'doc' => doc
    }

    @changes.handlers.each do |handler|
      handler.expects(:delete).with(doc)
    end

    @changes.send(:process_row, row)

    assert_equal @changes.database[CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE].first.fetch(:highest_sequence), '9'
  end

  def test_returning_schema
    schema = mock
    CouchdbToSql::Schema.expects(:new).once.with(@changes.database, :items).returns(schema)

    # Run twice to ensure cached
    assert_equal @changes.schema(:items), schema
    assert_equal @changes.schema(:items), schema
  end

  protected

  def build_sample_config
    connection_string = sql_connection_string

    @changes = CouchdbToSql::Changes.new(TEST_COUCHDB_URL) do
      database connection_string

      document type: 'Foo' do
      end

      document type: 'Bar' do
      end

      document type: 'Bar', special: true do
      end
    end
  end

  def sql_connection_string
    ENV.fetch('TEST_SQL_URL', 'sqlite:/')
  end
end
