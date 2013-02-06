# The Splunk Software Development Kit for Ruby (Preview Release)

This Splunk Software Development Kit (SDK) contains library code and examples 
designed to enable developers to build applications using Splunk.

Splunk is a search engine and analytic environment that uses a distributed
map-reduce architecture to efficiently index, search, and process large 
time-varying data sets.

The Splunk product is popular with system administrators for aggregation and
monitoring of IT machine data, security, compliance, and a wide variety of 
other scenarios that share a requirement to efficiently index, search, analyze,
and generate real-time notifications from large volumes of time series data.

The Splunk developer platform enables developers to take advantage of the 
same technology used by the Splunk product to build exciting new applications
that are enabled by Splunk's unique capabilities.

## This SDK is a Preview Release

1.  This Preview release is a pre-beta release. It is incomplete and may have 
    bugs. There is also a beta planned for release prior to a general release. 

2.  The Apache license only applies to this SDK and no other Software provided 
    by Splunk.

3.  Splunk, in using the Apache license, is not providing any warranties or 
    indemnification, or accepting any liabilities with the Preview SDK.

4.  Splunk is not accepting any Contributions to the Preview release of 
    the SDK. 
    All Contributions during the Preview SDK will be returned without review.

## Getting started with the Splunk SDK for Ruby

The Splunk SDK for Ruby contains code and some examples that show how to
programmatically interact with Splunk for a variety of scenarios, including
searching, saved searches, configuration, and many more. It's still not quite 
complete and things like Inputs are missing. Stay tuned.

### Requirements

Here's what you need to get going with the Splunk SDK for Ruby.

#### Splunk

If you haven't already installed Splunk, download it 
[here](http://www.splunk.com/download). For more information about installing 
and running Splunk and system requirements, see 
[Installing & Running Splunk](http://dev.splunk.com/view/SP-CAAADRV).

#### Ruby

The Splunk SDK for Ruby requires Ruby 1.9.2 or later.

#### Splunk SDK for Ruby

Get the Splunk SDK for Ruby from [GitHub](https://www.github.com) and clone the
resources to your computer. Use the following command:

    git clone https://github.com/splunk/splunk-sdk-ruby.git

### Installing the Splunk SDK for Ruby

We highly recommend that you use [Bundler](http://gembundler.com) to install 
the Splunk SDK for Ruby.

Add this line to your application's Gemfile:

    gem 'splunk-sdk-ruby'

And then execute:

    $ bundle

If you're not using Bundler, you can install it like this:

    $ gem build splunk-sdk-ruby.gemspec
    $ gem install splunk-sdk-ruby

### Examples and unit tests
For this Preview release, the examples and unit tests included with the Splunk 
SDK for Ruby are minimal. More are on the way.

#### Set up the .splunkrc file

To connect to Splunk, many of the SDK examples and unit tests take command-line
arguments that specify values for the host, port, and login credentials for
Splunk. For convenience during development, you can store these arguments as
key-value pairs in a text file named **.splunkrc**. Then, the SDK examples and 
unit tests use the values from the **.splunkrc** file when you don't specify 
them.

To use this convenience file, create a text file with the following format:

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

*   For example, on Mac OS X, save the file as: 

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
shouldn't be used for storing user credentials for production. And, if you're 
at all concerned about the security of your credentials, just enter them at 
the command line rather than saving them in this file. 

#### Run unit tests

We are adding more unit tests all the time. For now, run what we have.

In the base directory where you installed the Splunk SDK for Ruby, run

    $ rake test

It should run many tests without error.

To generate the code coverage of the test suite, run

    $ rake test COVERAGE=true

It will produce a directory called **coverage**. Open **coverage/index.html** to
see the coverage report.

#### View the examples

Be aware that, currently, the only examples are documented in-line with the code. 
You can view them at 
<http://splunk.github.com/splunk-sdk-ruby/doc/Splunk/Service.html>.

## Overview 

The Splunk library included in this SDK consists of two layers of APIs that 
can be used to interact with **splunkd**: the _binding_ layer and the 
_client_ layer. First, however, a word about XML...

### A word about XML

Ruby ships with the REXML library by default, but for most real world work,
you may want to use Nokogiri, which can be orders of magnitude faster. The Splunk
SDK for Ruby supports both. By default it will try to use Nokogiri, but will fall 
back to REXML if Nokogiri is not available. The value of the library in use is
kept in the global variable `$splunk_xml_library` (which will be either `:nokogiri`
or `:rexml`).

You can force your program to use a particular library by calling
**require_xml_library(**_library_**)** (where, again, _library_ is either `:nokogiri`
or `:rexml`). This method is in `lib/splunk_sdk_ruby/xml_shim.rb`, but will be
included when you include the whole SDK.

If you force your program to use a particular library, the SDK will no longer
try to fall back to REXML, but will issue a **LoadError**.

### The binding layer
This is the lowest layer of the Splunk SDK for Ruby. It is a thin wrapper around 
low-level HTTP capabilities, including:

* authentication and namespace URL management
* accessible low-level HTTP interface for use by developers who want
    to be close to the wire
* Atom response parser

Here is a simple example of using the binding layer. This example makes a REST 
call to Splunk returning an Atom feed of all users defined in the system:

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin", :password => 'password', :protocol => 'https').login
    puts c.get('authentication/users')    #Will spit out an ATOM feed in XML

Here is another example, but this time we convert the Atom feed to much cleaner
JSON:

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin", :password => 'password', :protocol => 'https').login
    users = Splunk::AtomResponseLoader::load_text(c.get('authentication/users')) #Will spit out JSON
    puts users['feed']['updated']

If you wish you can use _dot accessors_ to access the individual elements as 
long as they aren't in an array: 

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin", :password => 'password', :protocol => 'https').login
    users =  Splunk::AtomResponseLoader::load_text_as_record(c.get('authentication/users')) #Will spit out clean JSON
    pSDK for Rubyuts users.feed.updated   #Works
    puts users.feed.entry[0].title        #Throws exception
    puts users.feed.entry[0]['title']     #Works 

### The client layer
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
* Searching (One-shot, Asynchronous, Real-time, etc.)
* Restarting
* Configuration
* Messages
* Collections and Entities

Here is a simple example of using the _client_ layer. This example is the same 
as in the _binding_ layer. It returns all users in the system and displays 
their names:

    svc = Splunk::Service.connect(:username => 'admin', :password => 'password')
    svc.users.each {|user| puts user.name}

## Resources

You can find many examples throughout the SDK for Ruby class documentation:

* <http://splunk.github.com/splunk-sdk-ruby/doc/>

You can find anything having to do with developing on Splunk at the Splunk 
developer portal:

* <http://dev.splunk.com>

Splunk REST API reference documentation:

* <http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI>

## Community
<table>

<tr>
<td><b>Email</b></td>
<td><a href="mailto:devinfo@splunk.com">devinfo@splunk.com</a></td>
</tr>

<tr>
<td><strong>Forum</strong></td>
<td><a href="https://groups.google.com/forum/#!forum/splunkdev">https://groups.google.com/forum/#!forum/splunkdev</a>
</tr>

<tr>
<td><b>Issues</b>
<td><a href="https://github.com/splunk/splunk-sdk-ruby/issues/">https://github.com/splunk/splunk-sdk-ruby/issues/</a></td>
</tr>

<tr>
<td><b>Answers</b>
<td><a href="http://splunk-base.splunk.com/tags/ruby/">http://splunk-base.splunk.com/tags/ruby/</a></td>
</tr>

<tr>
<td><b>Blog</b>
<td><a href="http://blogs.splunk.com/dev/">http://blogs.splunk.com/dev/</a></td>
</tr>

<tr>
<td><b>Twitter</b>
<td><a href="http://twitter.com/#!/splunkdev">@splunkdev</a></td>
</tr>

</table>

### How to contribute

We aren't ready to accept code contributions yet, but will be shortly. Check 
this README for more updates soon.

### Support

* SDKs in Preview will not be Splunk supported. Once the SDK for Ruby moves to 
an Open Beta we will provide more detail on support. 

* Issues should be filed here: <https://github.com/splunk/splunk-sdk-ruby/issues>

### Contact Us
You can reach the Dev Platform team at <a href="mailto:devinfo@splunk.com">devinfo@splunk.com</a>.

## License

The Splunk Software Development Kit for Ruby is licensed under the Apache
License 2.0. Details can be found in the LICENSE file.

