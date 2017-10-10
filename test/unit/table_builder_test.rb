# frozen_string_literal: true

require 'test_helper'

class TableBuilderTest < Test::Unit::TestCase
  def described_class
    CouchdbToSql::TableBuilder
  end

  def setup
    @database = create_database
    @changes = mock
    @changes.stubs(:database).returns(@database)
    @changes.stubs(:schema).returns(CouchdbToSql::Schema.new(@database, :items))
    @handler = CouchdbToSql::DocumentHandler.new(@changes)
  end

  def test_init
    doc = CouchRest::Document.new('type' => 'Item', 'name' => 'Some Item', '_id' => '1234')
    @handler.document = doc
    @row = described_class.new(@handler, 'items')

    assert_equal @row.parent, @handler
    assert_equal @row.handler, @handler
    assert_equal @row.document, doc
    assert_equal @row.table_name, :items

    assert_equal @row.primary_key, :item_id

    # Also confirm that the automated calls were made
    assert_equal @row.attributes[:name], 'Some Item'
    assert_nil @row.attributes[:type]
    assert_nil @row.attributes[:_id]
    assert_equal @row.attributes[:item_id], '1234'

    assert_equal @row.instance_eval('@_collections.length'), 0
  end

  def test_init_with_primary_key
    doc = { 'type' => 'Item', 'name' => 'Some Item', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new(@handler, :items, primary_key: :entry_id)

    assert_equal @row.primary_key, :entry_id
  end

  def test_execute_with_new_row
    doc = { 'type' => 'Item', 'name' => 'Some Item', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new(@handler, :items)
    @row.execute

    items = @database[:items]
    item = items.first
    assert_equal items.where(item_id: '1234').count, 1
    assert_equal item[:name], 'Some Item'
  end

  def test_execute_with_new_row_with_time
    time = Time.now
    doc = { 'type' => 'Item', 'name' => 'Some Item', '_id' => '1234', 'created_at' => time.to_s }
    @handler.document = doc
    @row = described_class.new(@handler, :items)
    @row.execute
    items = @database[:items]
    item = items.first
    assert item[:created_at].is_a?(Time)
    assert_equal item[:created_at].to_s, time.to_s
  end

  def test_column_assign_with_symbol
    doc = { 'type' => 'Item', 'full_name' => 'Some Other Item', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items do
      column :name, :full_name
    end
    @row.execute

    data = @database[:items].first
    assert_equal data[:name], doc['full_name']
  end

  def test_column_assign_with_value
    doc = { 'type' => 'Item', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items do
      column :name, 'Force the name'
    end
    @row.execute

    data = @database[:items].first
    assert_equal data[:name], 'Force the name'
  end

  def test_column_assign_with_nil
    doc = { 'type' => 'Item', 'name' => 'Some Item Name', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items do
      column :name, nil
    end
    @row.execute
    data = @database[:items].first
    assert_equal data[:name], nil
  end

  def test_column_assign_with_empty_for_non_string
    doc = { 'type' => 'Item', 'name' => 'Some Item Name', 'created_at' => '', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items
    @row.execute
    data = @database[:items].first
    assert_equal data[:created_at], nil
  end

  def test_column_assign_with_integer
    doc = { 'type' => 'Item', 'count' => 3, '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items
    @row.execute
    data = @database[:items].first
    assert_equal data[:count], 3
  end

  def test_column_assign_with_integer_as_string
    doc = { 'type' => 'Item', 'count' => '1', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items
    @row.execute
    data = @database[:items].first
    assert_equal data[:count], 1
  end

  def test_column_assign_with_float
    doc = { 'type' => 'Item', 'price' => 1.2, '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items
    @row.execute
    data = @database[:items].first
    assert_equal data[:price], 1.2
  end

  def test_column_assign_with_float_as_string
    doc = { 'type' => 'Item', 'price' => '1.2', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items
    @row.execute
    data = @database[:items].first
    assert_equal data[:price], 1.2
  end

  def test_column_assign_with_block
    doc = { 'type' => 'Item', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items do
      column :name do
        'Name from block'
      end
    end
    @row.execute

    data = @database[:items].first
    assert_equal data[:name], 'Name from block'
  end

  def test_column_assign_with_no_field
    doc = { 'type' => 'Item', 'name' => 'Some Other Item', '_id' => '1234' }
    @handler.document = doc
    @row = described_class.new @handler, :items do
      column :name
    end
    @row.execute

    data = @database[:items].first
    assert_equal data[:name], doc['name']
  end

  protected

  def create_database
    database = Sequel.sqlite
    database.create_table :items do
      String :item_id
      String :name
      Integer :count
      Float :price
      Time :created_at
      index :item_id, unique: true
    end
    database
  end

  def create_many_to_many_items
    @database.create_table :group_items do
      String :group_id
      String :item_id
      index :group_id
    end
  end
end
