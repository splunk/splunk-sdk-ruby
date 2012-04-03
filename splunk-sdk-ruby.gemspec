# -*- encoding: utf-8 -*-
require File.expand_path('../lib/splunk-sdk-ruby/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Rob Das']
  gem.email         = ['rob@splunk.com']
  gem.description   = %q{Splunk SDK for Ruby}
  gem.summary       = %q{Ruby bindings to Splunk REST layer}
  gem.homepage      = 'http://dev.splunk.com'

  gem.executables   = `git ls-files -- bin/*`.split('\n').map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split('\n')
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split('\n')
  gem.name          = 'splunk-sdk-ruby'
  gem.require_paths = ['lib']
  gem.version       = Splunk::VERSION
  gem.required_ruby_version = '>=1.9.2'
end
