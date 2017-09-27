[![Build Status](https://travis-ci.org/ecraft/couch_tap.svg?branch=master)](https://travis-ci.org/ecraft/couch_tap)

# couchdb_to_sql

Utility to listen to a CouchDB changes feed and automatically insert, update,
or delete rows into an SQL database from matching key-value conditions of incoming documents.

`couchdb_to_sql` is heavily indebted to [samlown's](https://github.com/samlown) original [couch_tap](https://github.com/samlown/couch_tap) gem. We have added functionality needed for our particular use case, while still trying to keep it reasonably flexible and not too hardwired to the `ember-pouch` use case.

While CouchDB is awesome, business people probably won't be quite as impressed when they want to play around with the data. Regular SQL is generally accepted as being easy to use and much more widely supported by a larger range of commercial tools.

`couchdb_to_sql` will listen to incoming documents on a CouchDB server's [_changes feed](http://docs.couchdb.org/en/2.1.0/api/database/changes.html) in continuous mode, and automatically update rows of the SQL database tables defined in the conversion schema. The changes feed uses a sequence number allowing synchronization to be started and stopped at will.

[Sequel](http://sequel.jeremyevans.net/) is used to provide the connection to the database. This library can also be used for migrations, which is important for frequently changing schemas.

`couchdb_to_sql` takes a simple two-step approach converting documents to rows. When a change event is received for a matching `document` definition, each associated row is completely deleted. If the change is anything other than a delete event, the rows will be re-created with the new data. This makes things much easier when trying to deal with multi-level documents (i.e. documents of documents) and one-to-many table relationships.


## A `couchdb_to_sql` Project

`couchdb_to_sql` requires a configuration or filter definition that will allow incoming document changes to be identified and dealt with. The configuration file can either be hand-written or generated dynamically. (For our particular use case with `ember-pouch`, we have chosen to generate it based on the Ember model metadata. The script for this is unfortunately not open source at this time.)

The following example attempts to outline most of the key features of the DSL.

```ruby
# The couchdb database from which to request the changes feed
changes "http://user:pass@host:port/invoicing" do
  # # Optional flag which can be enabled to take advantage of Postgres 9.5's support for INSERT CONFLICT, e.g. upserts.
  # # Note: this only deals with the _couchdb_to_sql_sequences metadata table, not the actual CouchDB documents themselves.
  # upsert_mode

  # # Optional flag which can be enabled if ember-pouch is being used to populate the CouchDB database. ember-pouch uses a
  # # specially crafted format of the CouchDB documents, where all the data is placed in 'data' node and the 'id' follows a
  # # particular format. This flag makes couchdb_to_sql presume that all CouchDB documents for the given stream follow this format.
  # ember_pouch_mode

  # # Optional flag which can be enabled to enable a stricter mode, where processing will abort if an unhandled document is
  # # encountered.
  # fail_on_unhandled_document

  # # Optional path to a file containing a JSON array of sequences to skip. The 'seq' value of incoming documents will be compared
  # # to the values in this array.
  # skip_seqs_file 'skiplist.json'

  # The target database to which changes will be streamed.
  database "postgres://user:pass@localhost:5432/invoicing"

  # Simple automated copy, each property's value in the matching CouchDB document will be copied to the table field with the
  # same name.
  document 'type' => 'User' do
    table :users
  end

  document 'type' => 'Invoice' do

    table :invoices, :key => :invoice_id do

      # Copy columns from fields with different name
      column :updated_at, :updated_on
      column :created_at, :created_on

      # Manually set a value from document or fixed variable
      column :date, doc['date'].to_json
      column :added_at, Time.now

      # Set column values from a block.
      column :total do
        doc['items'].inject(0){ |sum,item| sum + item['total'] }
      end

      # Collections perform special synchronization in order to deal with one to one, or indeed many to many relationships.
      #
      # Rather than attempting a complex synchronization process, the current version of couchdb_to_sql will just DELETE all
      # current entries with a primary key id that matches that of the parent table.
      #
      # The foreign id key is assumed to be name of the parent table in singular form with `_id` appended.
      #
      # Each item provided in the array will be made available in the `#data` method, and index from `#index`. `#document`
      # continues to be the complete source document.
      #
      # Collections can be nested to create highly complex structures.
      #
      collection :groups do
        table :invoice_groups do

          collection :entries do
            table :invoice_entries, :key => :entry_id do
              column :date, data['date']
              column :updated_at, document['updated_at']
            end
          end
        end
      end

      # Collections can also be used on Many to Many relationships.
      collection :label_ids do
        table :invoice_labels do
          column :label_id, data
        end
      end
    end
  end
end
```

## DSL Summary

### changes

Defines which CouchDB database should be used to request the changes feed.

After loading the rest of the configuration, the service will connect to the database using Event Machine. As new changes come into the system, they will be managed in the background.


### connection

The Sequel URL used to connect to the destination database. Behind the scenes, `couchdb_to_sql` will check for a table named `couchdb_sequence` that contains a single row for the current changes sequence id, much like a migration id typically seen in a Rails database.

As changes are received from CouchDB, the current sequence will be updated to match.

#### document

When a document is received from the changes feed, it will be passed through each
`document` stanza looking for a match. Take the following example:

    document :type => 'Invoice' do |doc|
      # ...
    end

This will match all documents whose `type` property is equal to "Invoice". The document itself will be made available as a hash through the `doc` block variable.

`document` stanzas may be nested if required to provide further levels of filtering.

#### table

Each `table` stanza lets `couchdb_to_sql` know that all or part of the current document should be inserted into it. By default, the matching table's schema will be read and any field names that match a property in the top-level of the document will be inserted automatically.

One of the limitations of `couchdb_to_sql` is that all tables must have an id field as their primary key. In each row, the id's value will be copied from the `_id` of the document being imported. This is the only way that deleted documents can be reliably found and removed from the relational database.

#### column

#### collection

#### foreign_key


### Notes on deleted documents

Synchronizing a deleted document is generally a much more complicated operation. Given that the original document no longer exists in the CouchDB database, there is no way to know which document group and table the document was inserted into.

To get around this issue, `couchdb_to_sql` will search through all the tables defined for the database and delete rows that match the primary or foreign keys.

Obviously, this is very inefficient. Fortunately, CouchDB is not really suited to systems that require lots of document deletion, so hopefully this won't be too much of a problem.


## Testing

Run tests using rake, or individual tests as follows:

```shell
$ rake test TEST=test/unit/changes_test.rb
```

If you have disabled the "admin party" in CouchDB, you might have to manually specify the CouchDB URL. Like this:

```shell
$ COUCHDB_URL='http://admin:admin@127.0.0.1:5984/' bundle exec rake test
```

## Releasing a new version

- Merge all relevant pull requests
- Bump the version in the `VERSION` file. Follow Semantic Versioning principles. Do not prepend the version with a v. You don't need to commit or push after this step, it gets done automatically by the next step.
- `git release v1.0.x` (`brew install git-extras` if you are missing the `git release` command.)
- `bundle exec rake build release` (builds the `.gem` file and pushes it to Rubygems.org)
- `changelog-rs --latest` to regenerate the changelog which can then be copy-pasted to the [releases page](https://github.com/ecraft/couchdb_to_sql/releases). `curl https://sh.rustup.rs -sSf | sh && cargo install changelog-rs` if you don't have it installed. More info on [its web page](https://github.com/perlun/changelog-rs).
