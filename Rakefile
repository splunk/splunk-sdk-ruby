require 'rubygems' unless ENV['NO_RUBYGEMS']
require 'rubygems/package_task'
require 'rubygems/specification'
require 'rake/testtask'
require 'date'

spec = Gem::Specification.new do |s|
  s.name = 'splunk-sdk'
  s.version = '1.0.0'
  s.author = 'Rob Das'
  s.email = 'rdas@splunk.com'
  s.homepage = 'http://dev.splunk.com'
  s.summary = 'A gem that provides resources for managing Splunk.'
  s.description = s.summary
  s.has_rdoc = true
  s.extra_rdoc_files = ['README', 'LICENSE', 'TODO']
  s.require_path = 'lib'
  s.files = %w(LICENSE README Rakefile TODO) + Dir.glob('{lib,test}/**/*')
end


task :default => :test


desc 'install the gem locally'
task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VERSION}}
end


desc 'create a gemspec file'
task :make_spec do
  File.open("#{GEM}.gemspec", 'w') do |file|
    file.puts spec.to_ruby
  end
end

desc 'run reek on the codebase'
task :reek do
  sh %{find lib -name \*.rb | xargs reek}
end

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = File.join(['test', 'test_*.rb'])
  t.verbose = true
end
