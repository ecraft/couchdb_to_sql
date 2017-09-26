# frozen_string_literal: true

require 'test_helper'

class TableDestroyerTest < Test::Unit::TestCase
  def described_class
    CouchdbToSql::TableDestroyer
  end

  def setup
    @database = create_database
    @changes = mock
    @changes.stubs(:database).returns(@database)
    @changes.stubs(:schema).returns(CouchdbToSql::Schema.new(@database, :items))
    @handler = CouchdbToSql::DocumentHandler.new(@changes)
    @handler.document = { '_id' => '12345' }
  end

  def test_init
    @row = described_class.new(@handler, 'items')
    assert_equal @row.primary_key, :item_id
  end

  def test_init_override_primary_key
    @row = described_class.new(@handler, 'items', primary_key: 'foo_item_id')
    assert_equal @row.primary_key, :foo_item_id
  end

  def test_handler
    @row = described_class.new(@handler, :items)
    assert_equal @row.handler, @handler
  end

  def test_key_filter
    @row = described_class.new(@handler, :items)
    assert_equal @row.key_filter, item_id: '12345'
  end

  def test_execution_deletes_rows
    @database[:items].insert(name: 'Test Item 1', item_id: '12345')
    assert_equal @database[:items].count, 1, 'Did not create sample row correctly!'
    @row = described_class.new(@handler, :items)
    @row.execute
    assert_equal 0, @database[:items].count
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
