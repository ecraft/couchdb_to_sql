
# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'simplecov'

SimpleCov.start do
  add_filter 'test/'
end

require 'test/unit'
require 'mocha/setup'
require 'couchdb_to_sql'

TEST_COUCHDB_URL_PREFIX = ENV.fetch('COUCHDB_URL', 'http://127.0.0.1:5984/').freeze
TEST_COUCHDB_NAME = 'couchdb_to_sql'
TEST_COUCHDB_URL = File.join(TEST_COUCHDB_URL_PREFIX, TEST_COUCHDB_NAME)
TEST_COUCHDB = CouchRest.database(TEST_COUCHDB_URL)

def reset_test_couchdb!
  TEST_COUCHDB.recreate!
end

def reset_test_sql_db!(connection_string)
  Sequel.connect(connection_string) do |db|
    db.drop_table?(CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE)
  end
end
