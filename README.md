# The Splunk Software Development Kit for Ruby (Preview Release)

#### Version 0.1
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

1.  This Preview release is pre-beta, and therefore is incomplete and may have 
    bugs. A Beta release is planned prior to a general release. 

2.  The Apache license only applies to this SDK and no other software provided 
    by Splunk.

3.  Splunk, in using the Apache license, is not providing any warranties or 
    indemnification, or accepting any liabilities with the Preview of this SDK.

## Getting started with the Splunk SDK for Ruby

The Splunk SDK for Ruby contains code and some examples that show how to
programmatically interact with Splunk for a variety of scenarios, including
searching, saved searches, configuration, and many more. This SDK is still in progress and is missing features such as inputs. Stay tuned.


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

You can also download the SDK as a ZIP file, or install it directly (see below). 


### Installing the Splunk SDK for Ruby

If you have cloned the Splunk SDK for Ruby from GitHub, you should first
install the latest version of `rake`. For example, open a command prompt and enter the following:

    gem install rake

Then you can install the Splunk SDK for Ruby by running the following
command from the root of the repository (**/splunk-sdk-ruby**):

    rake install

Or, install the Splunk SDK for Ruby directly from RubyGems,
without cloning the repository or downloading the ZIP file, by running:

    gem install splunk-sdk-ruby

If you are using the Splunk SDK for Ruby in an application, we highly
recommend that you use [bundler](http://gembundler.com/), which installs the prerequisites when you deploy your application. Add the following line to your application's Gemfile to make bundler aware of the Splunk SDK for Ruby:

    gem 'splunk-sdk-ruby'

Then run the following command to install all of your application's
dependencies, including the Splunk SDK for Ruby:

    bundle

#### Examples

Examples are located in several locations within the Splunk SDK for Ruby:

* The **/splunk-sdk-ruby/examples/** directory
* Inline with the source code within the SDK
* In the documentation on the [Splunk Developer Portal](http://dev.splunk.com/view/ruby-sdk/SP-CAAAENQ).

#### Prepare for the unit tests

First, do not run the test suite against your production Splunk server! Install
another copy of Splunk and run the test suite against that.

Second, the versions of Rake and Test::Unit that ship with various Ruby versions
are broken. They work enough to install the SDK, but you cannot run the unit
tests or do any real development. You need to install the latest versions of each
from RubyGems:

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

*   For example, on Mac OS X, save the file as:

        ~/.splunkrc

*   On Windows, save the file as:

        C:\Users\currentusername\.splunkrc

    You might encounter errors in Windows when you try to name the file because
    ".splunkrc" looks like a nameless file with an extension. You can use
    the command line to create this file; go to the
    **C:\Users\currentusername** directory and enter the following command:

        Notepad.exe .splunkrc

    Click **Yes**, and then continue creating the file.

**Note**: Storing login credentials in the **.splunkrc** file is only for
convenience during development. This file isn't part of the Splunk platform and
shouldn't be used for storing user credentials for production. You should never
put the credentials of a Splunk instance whose security concerns you in a
**.splunkrc** file.

#### Run the unit tests

In the base directory where you installed the Splunk SDK for Ruby, run

    rake test

It should run many tests without error.

To generate code coverage of the test suite, first ensure you've installed
the latest version of [SimpleCov](http://rubygems.org/gems/simplecov): 

    gem install simplecov

To generate the code coverage, run:

    rake test COVERAGE=true

It will produce a directory called **coverage**. Open coverage/index.html to
see the coverage report.

**Note**: To protect your Splunk password, you may want to delete the .splunkrc 
file when you are done running the unit tests.

## Overview 

The Splunk library included in this SDK consists of two layers of API that 
can be used to interact with **splunkd** - the _binding_ layer and the 
_client_ layer. First, however, a word about XML...

### A word about XML

Ruby ships with the REXML library by default, but for most real world work,
you may want to use Nokogiri, which can be orders of magnitude faster. The Splunk
SDK for Ruby supports both. By default it will try to use Nokogiri, but will fall 
back to REXML if Nokogiri is not available. The value of the library in use is 
kept in the global variable `$splunk_xml_library` (which will be either
`:nokogiri` or `:rexml`).

You can force your program to use a particular library by calling
**require_xml_library(**_library_**)** (where, again, _library_ is either 
`:nokogiri` or `:rexml`). This method is in `lib/splunk_sdk_ruby/xml_shim.rb`, 
but will be included when you include the whole SDK.

If you force your program to use a particular library, the SDK will no longer
try to fall back to REXML, but will issue a **LoadError**.

### The binding layer
This is the lowest layer of the Splunk SDK for Ruby. It is a thin wrapper around 
low-level HTTP capabilities, including:

* authentication and namespace URL management
* accessible low-level HTTP interface for use by developers who want
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

You can read the Atom feed into a convenient Ruby object with the **AtomFeed**
class. It has two getter methods: **metadata**, which returns a hash of all the Atom
headers; and **entries**, which returns an array of hashes describing each Atom entry.

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin",
                            :password => 'password')
    c.login()

    response = c.request(:resource => ["authentication", "users"])
    users = Splunk::AtomFeed.new(response.body)
    puts users.metadata["updated"]
    puts users.entries[0]

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
* Saved Searches
* Searching (one-shot, asynchronous, real-time, and so on)
* Restarting
* Configuration
* Messages
* Collections and Entities

Here is example code to print the names of all the users in the system:

    service = Splunk::connect(:username => 'admin', :password => 'password')
    service.users.each do |user|
      puts user.name
    end

For more examples, see the **examples/** directory in the Splunk SDK for Ruby 
repository.

## Repository

<table>

<tr>
<tr>
<td><b>/examples</b></td>
<td>Examples demonstrating various SDK features</td>
</tr>

<tr>
<td><b>/lib</b></td>
<td>Source for the Splunk library modules</td>
</tr>

<tr>
<td><b>/test</b></td>
<td>Source for unit tests</td>
</tr>

</table>

### Changelog

The **CHANGELOG.md** file in the root of the repository contains a description
of changes for each version of the SDK. You can also find it online at
[https://github.com/splunk/splunk-sdk-ruby/blob/master/CHANGELOG.md](https://github.com/splunk/splunk-sdk-ruby/blob/master/CHANGELOG.md).

### Branches

The **master** branch always represents a stable and released version of the SDK.

## Documentation and resources

If you need to know more: 

* For all things developer with Splunk, your main resource is the [Splunk Developer Portal](http://dev.splunk.com).

* For conceptual and how-to documentation, see the [Overview of the Splunk SDK for Ruby](http://dev.splunk.com/view/SP-CAAAENQ).

* For API reference documentation, see the [Splunk SDK for Ruby Reference](http://docs.splunk.com/Documentation/RubySDK).

* For more about the Splunk REST API, see the [REST API Reference](http://docs.splunk.com/Documentation/Splunk/latest/RESTAPI).

* For more about about Splunk in general, see [Splunk>Docs](http://docs.splunk.com/Documentation/Splunk).

* For more about this SDK's repository, see our [GitHub Wiki](https://github.com/splunk/splunk-sdk-ruby/wiki/).

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

If you would like to contribute to the SDK, go here for more information:

* [Splunk and open source](http://dev.splunk.com/view/opensource/SP-CAAAEDM)

* [Individual contributions](http://dev.splunk.com/goto/individualcontributions)

* [Company contributions](http://dev.splunk.com/view/companycontributions/SP-CAAAEDR)

### Support

* SDKs in Preview are not Splunk supported. Once the Splunk SDK for Ruby moves to 
an open beta we will provide more detail on support.

* File any issues on 
   [GitHub](https://github.com/splunk/splunk-sdk-ruby/issues).

### Contact Us

You can reach the Dev Platform team at <a href="mailto:devinfo@splunk.com">
devinfo@splunk.com</a>.

## License

The Splunk Software Development Kit for Ruby is licensed under the Apache
License 2.0. Details can be found in the LICENSE file.
