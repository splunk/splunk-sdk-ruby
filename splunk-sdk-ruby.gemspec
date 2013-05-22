# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'splunk-sdk-ruby'
  gem.version       = '1.0.2'

  gem.authors       = ['Splunk']
  gem.email         = ['devinfo@splunk.com']
  gem.description   = %q{Splunk SDK for Ruby}
  gem.summary       = %q{Ruby bindings to Splunk REST layer}
  gem.homepage      = 'http://dev.splunk.com'
  gem.license       = 'APL2'

  gem.required_ruby_version = '>=1.9.2'
  gem.add_dependency 'jruby-openssl', '~>0.7.7' if RUBY_PLATFORM == "java"
  gem.add_dependency 'rake', '~>10'
  gem.add_development_dependency 'test-unit'

  gem.files         = Dir['{lib,examples,test}/**/*',
                          'CHANGELOG.md', 
                          'LICENSE', 
                          'README.md',
                          'Gemfile', 
                          'Rakefile', 
                          'splunk-sdk-ruby.gemspec']
  gem.test_files    = Dir['test/**/*']
  gem.require_paths = ['lib']
end
