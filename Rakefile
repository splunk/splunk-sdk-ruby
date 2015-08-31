require 'rubygems' unless ENV['NO_RUBYGEMS']
require 'rubygems/package_task'
require 'rubygems/specification'
require 'rake/testtask'
require 'date'

task :default => :help

desc "Print help on using the Rakefile for the Ruby SDK for Splunk."
task :help do
  puts "Rake commands for the Ruby SDK for Splunk:"
  puts "  rake install: Install the SDK in your current Ruby environment."
  puts "  rake test: Run the unit test suite."
  puts "  rake test COVERAGE=true: Run the unit test suite with code coverage."
end

desc "install the gem locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VERSION}}
end

Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/test_*.rb"
  t.options = "-v"
end
