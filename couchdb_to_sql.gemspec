# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name          = 'couchdb_to_sql'
  s.version       = `cat VERSION`.strip
  s.date          = File.mtime('VERSION')
  s.summary       = 'Listen to a CouchDB changes feed and create rows in a relational database in real-time.'
  s.description   = "couchdb_to_sql provides a DSL that allows complex CouchDB documents to be converted into rows in a RDBMS' " \
                    'table. The stream of events received from the CouchDB changes feed will trigger documents to be fed into a ' \
                    'matching filter block and saved in the database.'
  s.authors       = ['Sam Lown', 'Per Lundberg', 'Jens Nockert', 'Andreas Finne']
  s.homepage      = 'https://github.com/ecraft/couchdb_to_sql'
  s.license       = 'MIT'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'activesupport', '~> 5.0'
  s.add_dependency 'couchrest', '~> 2.0'
  s.add_dependency 'httpclient', '~> 2.6'
  s.add_dependency 'logging_library', '~> 1.0', '>= 1.0.5'
  s.add_dependency 'sequel', '>= 4.36.0'

  s.add_development_dependency 'mocha'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'test-unit', '~> 3.2'
end
