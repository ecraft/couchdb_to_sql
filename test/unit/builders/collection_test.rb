# frozen_string_literal: true

require 'test_helper'

module Builders
  class CollectionTest < Test::Unit::TestCase
    def setup
      @parent = mock
    end

    def test_initialize_collection
      @collection = CouchdbToSql::Builders::Collection.new(@parent, :items) do
        # nothing
      end
      assert_equal @collection.parent, @parent
      assert_equal @collection.field, :items
    end

    def test_raise_error_if_no_block
      assert_raise ArgumentError do
        @collection = CouchdbToSql::Builders::Collection.new(@parent, :items)
      end
    end

    def test_defining_table
      @parent.expects(:data).returns('items' => [])
      @collection = CouchdbToSql::Builders::Collection.new(@parent, :items) do
        table :invoice_items do
          # nothing
        end
      end
    end

    def test_defining_table_with_one_item
      @parent.expects(:data).returns('items' => [{ 'name' => 'Item 1' }])
      block = lambda do
        # nothing
      end
      CouchdbToSql::Builders::Table.expects(:new).with(@parent, :invoice_items, { data: { 'name' => 'Item 1' } }, &block)
      @collection = CouchdbToSql::Builders::Collection.new(@parent, :items) do
        table :invoice_items, &block
      end
    end

    def test_defining_table_with_two_items
      @parent.expects(:data).returns('items' => [{ name: 'Item 1' }, { name: 'Item 2' }])
      CouchdbToSql::Builders::Table.expects(:new).twice
      @collection = CouchdbToSql::Builders::Collection.new(@parent, :items) do
        table :invoice_items
      end
    end

    def test_defining_table_with_null_data
      assert_nothing_raised do
        @parent.expects(:data).returns('items' => nil)
        CouchdbToSql::Builders::Table.expects(:new).never
        @collection = CouchdbToSql::Builders::Collection.new(@parent, :items) do
          table :invoice_items
        end
      end
    end

    def test_execution
      @table = mock
      CouchdbToSql::Builders::Table.expects(:new).twice.returns(@table)
      @parent.expects(:data).returns('items' => [{ name: 'Item 1' }, { name: 'Item 2' }])
      @collection = CouchdbToSql::Builders::Collection.new(@parent, :items) do
        table :invoice_items
      end
      @table.expects(:execute).twice
      @collection.execute
    end
  end
end
