# The Splunk Software Development Kit for Ruby (Preview Release)

This SDK contains library code and examples designed to enable developers to
build applications using Splunk.

Splunk is a search engine and analytic environment that uses a distributed
map-reduce architecture to efficiently index, search and process large 
time-varying data sets.

The Splunk product is popular with system administrators for aggregation and
monitoring of IT machine data, security, compliance and a wide variety of 
other scenarios that share a requirement to efficiently index, search, analyze
and generate real-time notifications from large volumes of time series data.

The Splunk developer platform enables developers to take advantage of the 
same technology used by the Splunk product to build exciting new applications
that are enabled by Splunk's unique capabilities.

## License

The Splunk Software Development Kit for Ruby is licensed under the Apache
License 2.0. Details can be found in the file LICENSE.

## This SDK is a Preview Release

1.  This Preview release a pre-beta release.  There will also be a beta 
    release prior to a general release. It is incomplete and may^H^H^Hwill have bugs.

2.  The Apache license only applies to this SDK and no other Software provided 
    by Splunk.

3.  Splunk in using the Apache license is not providing any warranties, 
    indemnification or accepting any liabilities with the Preview SDK.

4.  Splunk is not accepting any Contributions to the Preview release of 
    the SDK.  
    All Contributions during the Preview SDK will be returned without review.

## Getting started with the Splunk SDK for Ruby

Here's what you need to get going with the Splunk Ruby SDK.

### Splunk

If you haven't already installed Splunk, download it here: 
http://www.splunk.com/download. For more about installing and running Splunk 
and system requirements, see Installing & Running Splunk 
(http://dev.splunk.com/view/SP-CAAADRV).

### Splunk SDK for Ruby

Get the Splunk SDK for Ruby from GitHub (https://github.com) and clone the
resources to your computer.  Use the following command:

    git clone https://github.com/splunk/splunk-sdk-ruby.git

### Installing

We highly recommend that you use _bundler_. See http://gembundler.com/ for more
info.

Add this line to your application's Gemfile:

    gem 'splunk-sdk-ruby'

And then execute:

    $ bundle

If you are not using bundler, than you can install it like this:

    $ gem build splunk-sdk-ruby.gemspec
    $ gem install splunk-sdk-ruby

or install it from Rubygems without fetching it from GitHub at all with

    $ gem install splunk-sdk-ruby

### Requirements

The Splunk Ruby SDK requires Ruby 1.9.2 or greater.

### Running the Unit Tests

First, do not run the test suite against your production Splunk server! Install
another copy and run it against that.

Second, the versions of Rake and Test::Unit that ship with various Ruby versions
are broken. They work enough to install the SDK, but you cannot run the unit
tests or do any real development. You need to install the latest versions:

    gem install rake
    gem install test-unit

The test suite reads the host to connect to and credentials to use from a
**.splunkrc** file. Create a text file with the following format:

    # Splunk host (default: localhost)
    host=localhost
    # Splunk admin port (default: 8089)
    port=8089
    # Splunk username
    username=admin
    # Splunk password
    password=changeme
    # Access scheme (default: https)
    scheme=https
    # Your version of Splunk (default: 5.0)
    version=5.0

Save the file as **.splunkrc** in the current user's home directory.

*   For example on Mac OS X, save the file as:

        ~/.splunkrc

*   On Windows, save the file as:

        C:\Users\currentusername\.splunkrc

    You might get errors in Windows when you try to name the file because
    ".splunkrc" looks like a nameless file with an extension. You can use
    the command line to create this file&mdash;go to the
    **C:\Users\currentusername** directory and enter the following command:

        Notepad.exe .splunkrc

    Click **Yes**, then continue creating the file.

**Note**: Storing login credentials in the **.splunkrc** file is only for
convenience during development. This file isn't part of the Splunk platform and
shouldn't be used for storing user credentials for production. You should never
put the credentials of any Splunk instance whose security concerns you in a
**.splunkrc** file.

To protect your Splunk password, you may want to delete this file when
you are done running the unit tests.

In the base directory where you installed the Splunk Ruby SDK, run

    $ rake test

It should run many tests without error.

To generate the code coverage of the test suite, run

    $ rake test COVERAGE=true

It will produce a directory called coverage. Open coverage/index.html to
see the coverage report.

## Overview 

The Splunk library included in this SDK consists of two layers of API that 
can be used to interact with splunkd - the _binding_ layer and the 
_client_ layer.

### A word about XML

Ruby ships with the REXML library by default, but for most real world work,
you will want to use Nokogiri, which is orders of magnitude faster. The Splunk
Ruby SDK supports both. By default it will try to use Nokogiri, and fall back
to REXML if Nokogiri is not available. The value of the library in use is
kept in the global variable `$splunk_xml_library` (which will be either
`:nokogiri` or `:rexml`).

You can force your program to use a particular library by calling
require_xml_library(_library_) (where, again, _library_ is either `:nokogiri`
or `:rexml`). This method is in `lib/splunk_sdk_ruby/xml_shim.rb`, but will be
included when you include the whole SDK.

If you force your program to use a particular library, the SDK will no longer
try to fall back to REXML, but will issue a LoadError, on the assumption that
if you really wanted Nokogiri that badly, we should probably tell you if you
don't get it.

### The Binding Layer
This is the lowest layer of the Splunk Ruby SDK. It is a thin wrapper around 
low-level HTTP capabilities, including:

* Authentication and namespace URL management
* Accessible low-level HTTP interface for use by developers who want
  to be close to the wire
* Atom feed parser

Here is a simple example of using the binding layer. This example makes a REST 
call to Splunk returning an Atom feed of all users defined in the system:

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin",
                            :password => 'password')
    c.login()

    # Will print an Atom feed in XML:
    puts c.request(:resource => ["authentication", "users"]).body

You can read the Atom feed into a convenient Ruby object with the AtomFeed
class. It has two getter methods: metadata, returning a hash of all the Atom
headers; and entries, returning an array of hashes describing each Atom entry.

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin",
                            :password => 'password')
    c.login()

    response = c.request(:resource => ["authentication", "users"])
    users = Splunk::AtomFeed.new(response.body)
    puts users.metadata["updated"]
    puts users.entries[0]

### The Client Layer

The _client_ layer builds on the _binding_ layer to provide a friendlier
interface to Splunk that abstracts away many of the lower level details of the 
_binding_ layer. It currently abstracts the following (with more to come):

* Authentication
* Apps
* Capabilities
* Server Info
* Loggers
* Settings
* Indexes
* Roles
* Users
* Jobs
* Saved Searches
* Searching (One-shot, Asynchronous, Real-Time, etc.)
* Restarting
* Configuration
* Messages
* Collections and Entities

Here is example code to print the names of all the users in the system:

    service = Splunk::connect(:username => 'admin', :password => 'password')
    service.users.each do |user|
      puts user.name
    end

For more examples, see the examples/ directory in the Ruby SDK repository.

## Resources

You can find anything having to do with developing on Splunk at the Splunk
developer portal:

* http://dev.splunk.com

The Splunk REST API is documented at:

* http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI

## Community

* Email: Stay connected with other developers building on Splunk: 
    https://groups.google.com/forum/#!forum/splunkdev 
* Issues: https://github.com/splunk/splunk-sdk-python/issues
* Answers: Check out this tag on Splunk answers for:  
    http://splunk-base.splunk.com/tags/python/
* Blog:  http://blogs.splunk.com/dev/
* Twitter: [@splunkdev](http://twitter.com/#!/splunkdev)

### How to contribute

If you would like to contribute to the SDK, go here for more information:

* [Splunk and open source](http://dev.splunk.com/view/opensource/SP-CAAAEDM)

* [Individual contributions](http://dev.splunk.com/goto/individualcontributions)

* [Company contributions](http://dev.splunk.com/view/companycontributions/SP-CAAAEDR)

### Support

* SDKs in Preview will not be Splunk supported.  Once the Ruby SDK moves to 
an open beta we will provide more detail on support.

* Issues should be filed here:  https://github.com/splunk/splunk-sdk-ruby/issues

### Contact Us

You can reach the Dev Platform team at devinfo@splunk.com


