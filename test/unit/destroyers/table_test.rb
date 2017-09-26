
# frozen_string_literal: true

require 'test_helper'

module Destroyers
  class TableTest < Test::Unit::TestCase
    def setup
      @database = create_database
      @changes = mock
      @changes.stubs(:database).returns(@database)
      @changes.stubs(:schema).returns(CouchdbToSql::Schema.new(@database, :items))
      @handler = CouchdbToSql::DocumentHandler.new(@changes)
      @handler.document = { '_id' => '12345' }
    end

    def test_init
      keys = []
      @handler.expects(:primary_keys).returns(keys)
      @row = CouchdbToSql::Destroyers::Table.new(@handler, 'items')

      assert_not_equal keys, @row.primary_keys
      assert_equal @row.primary_keys, [:item_id]
    end

    def test_init_override_primary_key
      @row = CouchdbToSql::Destroyers::Table.new(@handler, 'items', primary_key: 'foo_item_id')
      assert_equal @row.primary_keys, [:foo_item_id]
    end

    def test_handler
      @row = CouchdbToSql::Destroyers::Table.new(@handler, :items)
      assert_equal @row.handler, @handler
    end

    def test_key_filter
      @row = CouchdbToSql::Destroyers::Table.new(@handler, :items)
      assert_equal @row.key_filter, item_id: '12345'
    end

    def test_defining_collections
      @row = CouchdbToSql::Destroyers::Table.new @handler, :groups do
        collection :items do
          # Nothing
        end
      end
      assert_equal @row.instance_eval('@_collections.length'), 1
    end

    def test_defining_multiple_collections
      @row = CouchdbToSql::Destroyers::Table.new @handler, :groups do
        collection :items do
          # Nothing
        end
        collection :groups do
          # Nothing
        end
      end
      assert_equal @row.instance_eval('@_collections.length'), 2
    end

    def test_execution_deletes_rows
      @database[:items].insert(name: 'Test Item 1', item_id: '12345')
      assert_equal @database[:items].count, 1, 'Did not create sample row correctly!'
      @row = CouchdbToSql::Destroyers::Table.new(@handler, :items)
      @row.execute
      assert_equal 0, @database[:items].count
    end

    def test_execution_on_collections
      @col = mock
      CouchdbToSql::Destroyers::Collection.expects(:new).twice.returns(@col)
      @row = CouchdbToSql::Destroyers::Table.new @handler, :groups do
        collection :items do
          # Nothing
        end
        collection :groups do
          # Nothing
        end
      end
      @col.expects(:execute).twice
      @row.execute
    end

    def test_column_returns_nil
      @row = CouchdbToSql::Destroyers::Table.new @handler, :item
      assert_nil @row.column
    end

    def test_document_returns_empty
      @row = CouchdbToSql::Destroyers::Table.new @handler, :item
      assert_empty @row.document
      assert_empty @row.doc
    end

    def test_data_returns_empty
      @row = CouchdbToSql::Destroyers::Table.new @handler, :item
      assert_empty @row.data
    end

    protected

    def create_database
      database = Sequel.sqlite
      database.create_table :items do
        String :item_id
        String :name
        Time :created_at
        index :item_id, unique: true
      end
      database.create_table :groups do
        String :group_id
        String :name
        Time :created_at
        index :group_id, unique: true
      end
      database
    end
  end
end
