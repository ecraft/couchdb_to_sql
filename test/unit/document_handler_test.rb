
# frozen_string_literal: true

require 'test_helper'

class DocumentHandlerTest < Test::Unit::TestCase
  def test_init
    @handler = CouchdbToSql::DocumentHandler.new 'changes' do
      # nothing
    end
    assert_equal @handler.changes, 'changes'
  end

  def test_handles_with_basic_hash
    @handler = CouchdbToSql::DocumentHandler.new 'changes', type: 'Item'
    doc = { 'type' => 'Item', '_id' => '1234' }
    assert @handler.handles?(doc)
    doc = { 'type' => 'Client', '_id' => '1234' }
    assert !@handler.handles?(doc)
  end

  def test_handles_with_multi_level_hash
    @handler = CouchdbToSql::DocumentHandler.new 'changes', type: 'Item', foo: 'bar'
    doc = { 'type' => 'Item', 'foo' => 'bar', '_id' => '1234' }
    assert @handler.handles?(doc)
    doc = { 'type' => 'Item', '_id' => '1234' }
    assert !@handler.handles?(doc)
    doc = { 'foor' => 'bar', '_id' => '1234' }
    assert !@handler.handles?(doc)
  end

  def test_id
    @handler = CouchdbToSql::DocumentHandler.new 'changes' do
      table :items
    end
    @handler.document = { '_id' => '12345' }
    assert_equal @handler.id, '12345'
  end

  def test_insert
    @handler = CouchdbToSql::DocumentHandler.new 'changes' do
      table :items
    end
    @handler.expects(:table).with(:items)
    doc = { 'type' => 'Foo', '_id' => '1234' }
    @handler.insert(doc)
    assert_equal @handler.document, doc
  end

  def test_delete
    @handler = CouchdbToSql::DocumentHandler.new 'changes' do
      table :items
    end
    @handler.expects(:table).with(:items)
    @handler.delete('_id' => '1234')
    assert_equal @handler.id, '1234'
  end

  def test_table_definition_on_delete
    @handler = CouchdbToSql::DocumentHandler.new 'changes' do
      @mode = :delete # Force delete mode!
    end
    @handler.instance_eval('@mode = :delete')
    @table = mock
    @table.expects(:execute)
    CouchdbToSql::Destroyers::Table.expects(:new).with(@handler, :items, {}).returns(@table)
    @handler.table(:items)
  end

  def test_table_definition_on_insert
    @handler = CouchdbToSql::DocumentHandler.new 'changes' do
      # Force insert mode!
    end
    @handler.instance_eval('@mode = :insert')
    @table = mock
    @table.expects(:execute)
    CouchdbToSql::Builders::Table.expects(:new).with(@handler, :items, {}).returns(@table)
    @handler.table(:items)
  end
end
