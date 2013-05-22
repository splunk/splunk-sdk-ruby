#--
# Copyright 2011-2012 Splunk, Inc.
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
#++

# This script runs all the examples shipped with the SDK, one after another,
# editing their source on the fly to set the correct login parameters for
# your Splunk instance. It pauses between each to ask if this was correct.

require 'optparse'

def main(argv)
  credentials = {
    :host => "localhost",
    :port => 8089,
    :username => "admin",
    :password => "changeme",
  }
  
  parser = OptionParser.new do |op|
    op.on("--host HOSTNAME", String, "Set Splunk host (default: localhost)") do |s|
      credentials[:host] = s
    end

    op.on("--port PORT", Integer, "Set Splunk port (default: 8089)") do |p|
      credentials[:port] = p
    end

    op.on("--username USERNAME", String, "Set username for login (default: admin)") do |s|
      credentials[:username] = s
    end

    op.on("--password PASSWORD", String, "Set password for login (default: changeme)") do |s|
      credentials[:password] = s
    end
  end

  parser.parse!(argv)

  # The examples are all named as 1_something.rb, 2_something.rb in the same
  # directory as this script.
  example_path = File.dirname(File.expand_path(__FILE__))
  example_files = Dir.entries(example_path).
    select() {|s| s.match('^\\d_.+\\.rb')}.
    map() {|s| File.join(example_path, s)}

  # Add the path to the Splunk SDK for Ruby.
  $LOAD_PATH.push(File.join(File.dirname(example_path), "lib"))

  # Run 
  example_files.each do |p|
    run_example(p, credentials)
  end
end


module Kernel
  require 'stringio'

  def eval_stdout
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    yield
    return [out.string, err.string]
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end
end

def run_example(abspath, credentials)
    handle = File.open(abspath)
    contents = handle.read()
    handle.close()

    credentials.each_pair do |key, value|
      contents.gsub!(Regexp.new(key.inspect + "\s*=>\s*[^,\\n]+"),
                     key.inspect + " => " + value.inspect)
    end
 
    begin
      output = eval_stdout do
        eval(contents)
      end
      puts "SUCCESS: " + abspath
      puts "  stdout was:"
      puts output[0].lines.map() {|s| "    " + s}.join("")
      if output[1] != ""
        puts "  stderr was:"
        puts output[1].lines.map() {|s| "    " + s}.join("")
      end
      puts
    rescue Exception => e
      puts "FAILURE: " + abspath
      puts "  using credentials " + credentials.to_s
      puts "  Error was:"
      puts e.to_s.lines.map() {|s| "    " + s}.join("")
      puts
    end
end

if __FILE__ == $0
  main(ARGV)
end
