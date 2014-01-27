#!/usr/bin/env ruby

# Copyright 2014 Splunk, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"): you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

require 'optparse'

# release.sh - Push a new release of the Ruby SDK.
#
# See the instructions on the project's GitHub wiki on
# issuing a new release:
#
# https://github.com/splunk/splunk-sdk-ruby/wiki/Issuing-a-new-release
#
# This script assumes that you have already made all the necessary changes
# on a release/*version* branch. It will merge the release branch to
# master, backmerge the changes to develop, push the branches to
# GitHub, and push a copy of the gem to RubyGems.

# Usage: release.rb [--username username] [--password password]
#
#   username, password -- credentials to log into RubyGems
#
# release.rb assumes that you are on a branch release/*version* that
# matches the version in the gemspec file. If that is not true, it
# will exit with an error.

# If you have already logged into RubyGems on this machine, you
# should have a credential in ~/.gem/credentials, and this script
# will read that. If there is no such file, the script will require
# the --username and --password arguments.
# ###

# Do we have a credential to log into RubyGems?
if File.exists?(Dir.home() + "/.gem/credentials")
  puts "Found credentials file for RubyGems."
  provide_login = false
else
  provide_login = true
  puts "No credentials file found for RubyGems."
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: release.rb [--username USERNAME] [--password PASSWORD]"

    opts.on("--username", "Provide username for RubyGems") do |v|
      options[:username] = v
    end

    opts.on("--password", "Provide password for RubyGems") do |v|
      options[:password] = v
    end
  end.parse!

  if options[:username].nil? || options[:password].nil?
    puts "Must provide a username and password for RubyGems."
    exit -1
  end
end


# Change to the SDK's root directory.
sdk_root = File.dirname(File.expand_path(__FILE__))
Dir.chdir(sdk_root)

# Find the version of the current git branch.
current_git_branch = `git rev-parse --abbrev-ref HEAD`.chomp()
m = Regexp.new('^release/([0-9\.]+)$').match(current_git_branch)
if m
  version = m.captures[0]
  puts "Releasing version #{version} from branch #{current_git_branch}"
else
  throw Exception.new("Must be on a branch of the form release/*version*")
end

# Find the version specified in the gemspec.
gemspec_filename = "splunk-sdk-ruby.gemspec"
gemspec = File.open(gemspec_filename)
gemspec.each_line do |line|
  m = Regexp.new('^\s*gem.version\s*=\s*\'([0-9\.]+)\'\s*$').match(line)
  if m
    gemspec_version = m.captures[0]
    if gemspec_version != version
      throw Exception.new("Version #{gemspec_version} in gemspec did not match branch version #{version} from git")
    else
      puts "Version #{gemspec_version} found in #{gemspec_filename} matches git branch."
    end
    break
  end
end
gemspec.close()

puts "Merging to master in git."
`git checkout master`
`git merge --no-ff -m "Release #{version}" release/#{version}`
`git tag #{version}`
# Push everything to GitHub
`git push origin master:master`
`git push --tags`

puts "Pushing gem."
`gem update --system`
`gem build splunk-sdk-ruby.gemspec`
if provide_login
  `echo -e "#{options[:username]}\n#{options[:password]}\n" | gem push splunk-sdk-ruby-#{version}.gem`
else
  `gem push splunk-sdk-ruby-#{version}.gem`
end

puts "Verifying that the pushed RubyGem works."
Dir.chdir(Dir.home())

gemset_name = "#{version}-test-gemset".chomp()
current_ruby = `rvm current`.chomp()

puts `rvm gemset create #{gemset_name}`

# Use the gemset we have created
ENV["GEM_HOME"]="#{Dir.home()}/.rvm/gems/#{current_ruby}@#{gemset_name}"
ENV["GEM_PATH"]="#{Dir.home()}/.rvm/gems/#{current_ruby}@#{gemset_name}:#{Dir.home()}/.rvm/gems/#{current_ruby}@global"

puts `gem install rake test-unit nokogiri splunk-sdk-ruby`
installed_version = `ruby -e "require 'splunk-sdk-ruby'; puts Splunk::VERSION"`.chomp()

puts `yes yes | rvm gemset delete #{gemset_name}`

Dir.chdir(sdk_root)

if installed_version == version
  puts "Pushed RubyGem works."
  `git push origin :release/#{version}`
  `git branch -d release/#{version}`
  `git checkout develop`
  `git merge master`
  `git push origin develop:develop`
  `git checkout master`
  
  puts "Creating zip file and hashes."
  Dir.chdir("..")
  `curl https://github.com/splunk/splunk-sdk-ruby/archive/master.zip -o splunk-sdk-ruby-#{version}.zip`
  `md5sum splunk-sdk-ruby-#{version}.zip > splunk-sdk-ruby-#{version}.zip.hashes`
  `sha512sum splunk-sdk-ruby-#{version}.zip >> splunk-sdk-ruby-#{version}.zip.hashes`
else
  puts 'Splunk SDK for Ruby #{version} did not install from RubyGems! Something has gone wrong!'
fi
  
end
