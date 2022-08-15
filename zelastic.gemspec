# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zelastic/version'

Gem::Specification.new do |spec|
  spec.name          = 'zelastic'
  spec.version       = Zelastic::VERSION
  spec.authors       = ['carwow Developers']
  spec.email         = ['developers@carwow.co.uk']

  spec.summary       = 'Zero-downtime (re-)indexing of ActiveRecord models into Elasticsearch.'
  spec.description   = 'An index manager for Elasticsearch and ActiveRecord'
  spec.homepage      = 'https://github.com/carwow/zelastic'
  spec.license       = 'MIT'

  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'

  spec.add_development_dependency 'activerecord'
  spec.add_development_dependency 'bundler', '~> 2'
  spec.add_development_dependency 'carwow_rubocop', '~> 4'
  spec.add_development_dependency 'elasticsearch', '>= 5', '< 8'
  spec.add_development_dependency 'pry', '~> 0.14'
  spec.add_development_dependency 'rake', '~> 13'
  spec.add_development_dependency 'rspec', '~> 3'
end
