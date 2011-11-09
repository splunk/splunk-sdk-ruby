require 'rubygems' unless ENV['NO_RUBYGEMS']
require 'rubygems/package_task'
require 'rubygems/specification'
require 'rake/testtask'
require 'date'

spec = Gem::Specification.new do |s|
  s.name = "splunk-sdk"
  s.version = "0.0.1"
  s.author = "Your Name"
  s.email = "Your Email"
  s.homepage = "http://example.com"
  s.description = s.summary = "A gem that provides..."
  #s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "LICENSE", 'TODO']
  
  # Uncomment this to add a dependency
  # s.add_dependency "foo"
  
  s.require_path = 'lib'
  #s.autorequire = GEM
  s.files = %w(LICENSE README Rakefile TODO) + Dir.glob("{lib,test}/**/*")
end

task :default => :test

desc "install the gem locally"
task :install => [:package] do
  sh %{sudo gem install pkg/#{GEM}-#{GEM_VERSION}}
end

desc "create a gemspec file"
task :make_spec do
  File.open("#{GEM}.gemspec", "w") do |file|
    file.puts spec.to_ruby
  end
end

Rake::TestTask.new do |t|
    t.libs << 'lib' << 'test'
    t.pattern = 'test/tc_*.rb'
    t.verbose = true
end


