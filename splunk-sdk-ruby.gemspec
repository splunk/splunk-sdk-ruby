# -*- encoding: utf-8 -*-
require File.expand_path('../lib/splunk-sdk-ruby/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Rob Das']
  gem.email         = ['rob@splunk.com']
  gem.description   = %q{Splunk SDK for Ruby}
  gem.summary       = %q{Ruby bindings to Splunk REST layer}
  gem.homepage      = 'http://dev.splunk.com'

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = 'splunk-sdk-ruby'
  gem.require_paths = ['lib']
  gem.version       = '1.0.0'
  gem.required_ruby_version = '>=1.9.2'
  gem.add_dependency 'libxml-jruby', '~>1.0.0'
  gem.add_dependency 'json_pure', '~>1.6.4'
  gem.add_dependency 'json-stream', '~>0.1.2'
  gem.add_dependency 'netrc', '~>0.5'
  gem.add_dependency 'rest-client', '~>1.6.7'
  gem.add_dependency 'uuid', '~>2.3.4'
end
