
# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'test/unit'
require 'mocha/setup'
require 'couchdb_to_sql'

TEST_DB_HOST = ENV.fetch('COUCHDB_URL', 'http://127.0.0.1:5984/').freeze
TEST_DB_NAME = 'couchdb_to_sql'
TEST_DB_ROOT = File.join(TEST_DB_HOST, TEST_DB_NAME)
TEST_DB = CouchRest.database(TEST_DB_ROOT)

def reset_test_db!
  TEST_DB.recreate!
end
