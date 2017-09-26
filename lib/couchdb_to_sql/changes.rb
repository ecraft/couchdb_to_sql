# frozen_string_literal: true

module CouchdbToSql
  class Changes
    COUCHDB_HEARTBEAT  = 30
    INACTIVITY_TIMEOUT = 70
    RECONNECT_TIMEOUT  = 15

    attr_reader :source, :schemas, :handlers

    attr_accessor :highest_sequence

    # Start a new Changes instance by connecting to the provided
    # CouchDB to see if the database exists.
    def initialize(opts = '', &block)
      raise 'Block required for changes!' unless block_given?

      @schemas  = {}
      @handlers = []
      @source   = CouchRest.database(opts)
      @http     = HTTPClient.new
      @http.debug_dev = STDOUT if ENV.key?('DEBUG')
      @skip_seqs = Set.new

      log_info 'Connected to CouchDB'

      # Prepare the definitions
      @dsl_mode = true
      instance_eval(&block)
      @dsl_mode = false
    end

    #### DSL

    # Sets the `ember_pouch_mode` flag. In `ember-pouch` mode, all the data fields are expected to reside within a
    # `data` node in the document. More information on `ember-pouch` can be found
    # [here](https://github.com/nolanlawson/ember-pouch).
    #
    # @note Dual-purpose method, accepts configuration of setting or returns a previous definition.
    def ember_pouch_mode
      if @dsl_mode
        @ember_pouch_mode ||= true
      else
        @ember_pouch_mode
      end
    end

    # Sets the `upsert_mode` flag. When running in upsert mode, Sequel's insert_conflict mode is being used. More information
    # about that can be found
    # [here](http://sequel.jeremyevans.net/rdoc/files/doc/postgresql_rdoc.html#label-INSERT+ON+CONFLICT+Support)
    #
    # @note Dual-purpose method, accepts configuration of setting or returns a previous definition.
    def upsert_mode
      if @dsl_mode
        @upsert_mode ||= true
      else
        @upsert_mode
      end
    end

    # Sets the "fail on unhandled document" flag, which will turn log errors into runtime exceptions if an unhandled document is
    # encountered.
    #
    # @note Dual-purpose method, accepts configuration of setting or returns a previous definition.
    def fail_on_unhandled_document
      if @dsl_mode
        @fail_on_unhandled_document ||= true
      else
        @fail_on_unhandled_document
      end
    end

    # @note Dual-purpose method, accepts configuration of database
    # or returns a previous definition.
    def database(opts = nil)
      if opts
        @database ||= Sequel.connect(opts)
        find_or_create_sequence_number
      end
      @database
    end

    def document(filter = {}, &block)
      @handlers << DocumentHandler.new(self, filter, &block)
    end

    def skip_seqs_file(file_path)
      file_contents = File.read(file_path)
      seqs = JSON.parse(file_contents)
      @skip_seqs |= Set.new(seqs)
    end

    #### END DSL

    def schema(name)
      @schemas[name.to_sym] ||= Schema.new(database, name)
    end

    # Start listening to the CouchDB changes feed. By this stage we should have
    # a sequence id so we know where to start from and all the filters should
    # have been prepared.
    def start
      perform_request
    end

    protected

    def perform_request
      raise 'Internal error: Highest_sequence is expected to be non-nil' unless highest_sequence
      log_info "listening to changes feed from sequence number: #{highest_sequence}"

      url = File.join(source.root.to_s, '_changes')
      uri = URI.parse(url)

      # Authenticate?
      if uri.user.present? && uri.password.present?
        @http.set_auth(source.root, uri.user, uri.password)
      end

      # Make sure the request has the latest sequence
      query = {
        since: highest_sequence,
        feed: 'continuous',
        heartbeat: COUCHDB_HEARTBEAT * 1000
      }

      num_rows = 0

      loop do
        # Perform the actual request for chunked content
        @http.get_content(url, query) do |chunk|
          rows = chunk.split("\n")
          rows.each { |row|
            parsed_row = JSON.parse(row)
            process_row(parsed_row)

            num_rows += 1
            log_info "Processed #{num_rows} rows" if (num_rows % 10_000) == 0
          }
        end
        log_error "connection ended, attempting to reconnect in #{RECONNECT_TIMEOUT}s..."
        wait RECONNECT_TIMEOUT
      end
    rescue HTTPClient::TimeoutError, HTTPClient::BadResponseError => e
      log_error "connection failed: #{e.message}, attempting to reconnect in #{RECONNECT_TIMEOUT}s..."
      wait RECONNECT_TIMEOUT
      retry
    end

    def process_row(row)
      id = row['id']
      seq = row['seq']

      return if id =~ /^_design/
      return if @skip_seqs.include?(seq)

      if id
        # Wrap the whole request in a transaction
        database.transaction do
          if row['deleted']
            # Delete all the entries
            log_info "received DELETE seq. #{seq} id: #{id}"
            handlers.each { |handler| handler.delete('_id' => id) }
          else
            log_debug "received CHANGE seq. #{seq} id: #{id}"
            doc = fetch_document(id)

            document_handlers = find_document_handlers(doc)
            if document_handlers.empty?
              message = 'No document handlers found for document. ' \
                "Document data: #{doc.inspect}, seq: #{seq}, source: #{@source.name}"
              raise InvalidDataError, message if fail_on_unhandled_document

              log_error message
            end

            document_handlers.each do |handler|
              # Delete all previous entries of doc, then re-create
              handler.delete(doc)
              handler.insert(doc)
            end
          end

          update_sequence_tabl(seq)
        end # transaction
      elsif row['last_seq']
        # Sometimes CouchDB will send an update to keep the connection alive
        log_info "received last seq: #{row['last_seq']}"
      end
    end

    def fetch_document(id)
      doc = source.get(id)

      if ember_pouch_mode
        ember_pouch_transform_document(doc)
      else
        doc
      end
    end

    def ember_pouch_transform_document(doc)
      if doc.key?('data')
        doc['id'] = doc['_id'].split('_2_', 2).last
        doc.merge(doc.delete('data'))
      else
        doc
      end
    end

    def find_document_handlers(document)
      @handlers.select { |row| row.handles?(document) }
    end

    def find_or_create_sequence_number
      unless database.table_exists?(CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE)
        create_sequence_table
        sequence_table.insert(couchdb_database_name: source.name, created_at: DateTime.now)
      end

      row = sequence_table.where(couchdb_database_name: source.name).first
      self.highest_sequence = (row ? row.fetch(:highest_sequence) : '0')
    end

    def update_sequence_tabl(new_highest_sequence)
      if upsert_mode
        data = {
          couchdb_database_name: source.name,
          highest_sequence: new_highest_sequence,
          updated_at: DateTime.now
        }
        sequence_table
          .insert_conflict(target: :couchdb_database_name, update: data)
          .insert(data.merge(created_at: data[:updated_at]))
      else
        sequence_table
          .where(couchdb_database_name: source.name)
          .update(highest_sequence: new_highest_sequence)
      end

      self.highest_sequence = new_highest_sequence
    end

    def create_sequence_table
      database.create_table CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE do
        String :couchdb_database_name, primary_key: true
        String :highest_sequence, default: '0', null: false
        DateTime :created_at
        DateTime :updated_at
      end
    end

    def sequence_table
      database[CouchdbToSql::COUCHDB_TO_SQL_SEQUENCES_TABLE]
    end

    def logger
      CouchdbToSql.logger
    end

    def log_debug(message)
      logger.debug "#{source.name}: #{message}"
    end

    def log_info(message)
      logger.info "#{source.name}: #{message}"
    end

    def log_error(message)
      logger.error "#{source.name}: #{message}"
    end
  end
end
