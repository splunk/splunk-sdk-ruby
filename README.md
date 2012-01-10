# Splunk::Sdk::Ruby

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'splunk-sdk-ruby'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install splunk-sdk-ruby

## Usage

TODO: Write usage instructions here

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


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

The Splunk Software Development Kit for Java is licensed under the Apache
License 2.0. Details can be found in the file LICENSE.

## This SDK is a Preview Release

1.  This Preview release a pre-beta release.  There will also be a beta 
    release prior to a general release. It is incomplete and may^H^H^Hwill have bugs.

2.  The Apache license only applies to the SDK and no other Software provided 
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

cd <whatever directory you want to place the SDK directory into>
git clone https://github.com/splunk/splunk-sdk-ruby.git

#### Installing

Add this line to your application's Gemfile:

    gem 'splunk-sdk-ruby'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install splunk-sdk-ruby

#### Requirements

The Splunk Ruby SDK requires Ruby 1.9.2 or greater.

#### Running the Unit Tests

In the base directory where you installed the Splunk Ruby SDK, run

    $ rake test

It should run many tests without error.

Note that currently, the only examples are documented in-line with the code.  They
can be seen by pointing your browser to <SDK_HOME>/doc/index.html.  Look at the 
<b>Service</b> class for examples.



