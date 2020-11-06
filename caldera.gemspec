# frozen_string_literal: true

require_relative 'lib/caldera/version'

Gem::Specification.new do |spec|
  spec.name          = 'caldera'
  spec.version       = Caldera::VERSION
  spec.authors       = ['Matthew Carey']
  spec.email         = ['matthew.b.carey@gmailcom']

  spec.summary       = 'Lavalink client'
  spec.description   = 'Lavalink client for use with Discord libraries.'
  spec.homepage      = 'https://github.com/swarley/caldera'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = 'https://github.com/swarley/caldera/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'rubocop', '~> 0.93.1'
  spec.add_development_dependency 'rubocop-performance', '~> 1.8'
  spec.add_development_dependency 'yard', '~> 0.9.25'

  spec.add_dependency 'event_emitter', '~> 0.2.6'
  spec.add_dependency 'logging', '~> 2.3'
  spec.add_dependency 'permessage_deflate', '~> 0.1.4'
  spec.add_dependency 'websocket-driver', '~> 0.7.3'
end
