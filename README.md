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

## Getting started with the Splunk Ruby SDK

The Splunk Ruby SDK contains code and some examples that show how to
programattically interact with Splunk for a variety of scenarios including
searching, saved searches, configuration and many more. It's still not quite 
complete and things like Inputs are missing.  Stay tuned.

### Getting Started

Here's what you need to get going with the Splunk Ruby SDK.

#### Splunk

If you haven't already installed Splunk, download it here: 
http://www.splunk.com/download. For more about installing and running Splunk 
and system requirements, see Installing & Running Splunk 
(http://dev.splunk.com/view/SP-CAAADRV).

#### Splunk Ruby SDK

Get the Splunk Ruby SDK from GitHub (https://github.com) and clone the
resources to your computer.  Use the following commands:

cd <i>whatever directory you want to place the SDK directory into</i>
git clone https://github.com/splunk/splunk-sdk-ruby.git

#### Installing

We highly recommend that you use <bundler>

Add this line to your application's Gemfile:

    gem 'splunk-sdk-ruby'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install splunk-sdk-ruby

#### Requirements

The Splunk Ruby SDK requires Ruby 1.9.2 or greater.

#### Running the Unit Tests

1. Make sure that the password for Splunk user <b>admin</b> is <b>"password"</b>.  The unit
tests are hard-coded to that user/psw pair.  Make sure to put this back the way you had it
when you are done running the unit tests.

2. In the base directory where you installed the Splunk Ruby SDK, run

    $ rake test

It should run many tests without error.

Note that currently, the only examples are documented in-line with the code.  They
can be seen by pointing your browser to splunk-sdk-ruby/doc/Service.html.

## Overview 

The Splunk library included in this SDK consists of two layers of API that 
can be used to interact with splunkd - the _binding_ layer and the _client_ layer.

#### The Binding Layer
This is the lowest layer of the Splunk Ruby SDK. It is a thin wrapper around low-level HTTP capabilities, 
including:

* Handles authentication and namespace URL management
* Accessible low-level HTTP interface for use by developers who want
    to be close to the wire.
* Atom Response parser

Here is a simple example of using the binding layer. This example makes a REST call
to Splunk returning an Atom feed of all users defined in the system:

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin", :password => ADMIN_PSW, :protocol => 'https').login
    puts c.get('authentication/users') #Will spit out an ATOM feed in XML

Here is another example, but this time we convert the Atom feed to much cleaner JSON:

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin", :password => ADMIN_PSW, :protocol => 'https').login
    users = Splunk::AtomResponseLoader::load_text(c.get('authentication/users')) #Will spit out JSON
    puts users['feed']['updated']

If you wish you can use _dot accessors_ to access the individual elements as long as they aren't in 
an Array: 

    require 'splunk-sdk-ruby'

    c = Splunk::Context.new(:username => "admin", :password => ADMIN_PSW, :protocol => 'https').login
    users =  Splunk::AtomResponseLoader::load_text_as_record(c.get('authentication/users')) #Will spit out clean JSON
    puts users.feed.updated             #Works
    puts users.feed.entry[0].title      #Throws exception
    puts users.feed.entry[0]['title']   #Works 

#### The Client Layer
    



