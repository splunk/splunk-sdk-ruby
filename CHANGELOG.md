# Splunk SDK for Ruby Changelog

## Version 1.0.5

* Added support for basic authentication
* Added an example for load balanced search heads

## Version 1.0.4

* Added support for client certificates and path prefix.
* Added an option to specify a proxy server to use. Includes connect_via_proxy.rb example.
* Minor Fixes

## Version 1.0.3

* Splunk SDK for Ruby now works with Splunk 6.
* Fixed URL escaping of owners and apps in namespaces that contain special characters.

## Version 1.0.2

* Cosmetic changes to the repository only.

## Version 1.0.1

* Fixed Job#results to properly handle arguments.
	
## Version 1.0

* No bugs found during beta period.

## Version 0.8.1 (beta)

### Bugs fixed

* Fixed wrong version number in a few documentation files.

## Version 0.8.0 (beta)

### Breaking changes

* The _raw field in events is now returned as text, not XML. That is, all tags
  such as the sg elements, are removed, and all characters are unescaped. The
  XML is available from the segmented_raw method on the event, which returns a
  string containing the raw XML of the _raw field returned by the server.
* The severities in messages in Atom feeds are now strings instead of symbols.

### New features

* Added support for inputs via the Service#inputs method, and for modular
  input kinds via the Service#modular_input_kinds method.
* Added segmented_raw method to events returned by ResultsReader.

### Bugs fixed

* Added missing Splunk:: prefix in example in the docs for Service.
* Moved default "segmentation=none" option for asynchronous searches from
  Job#initialize to Job#events, Job#preview, and Job#results.

## Version 0.1.0 (preview)

### Breaking changes

* The Splunk SDK for Ruby now uses the same **.splunkrc** format as the other SDKs.
* Moved `Service#connect` to being a static method of the `Splunk` module, so you now call connect as

      service = Splunk::connect(...)

  instead of

      service = Splunk::Service.connect(...)
      
* **aloader.rb** and the `AtomResponseLoader` it contained have been replaced in their entirety by atomfeed.rb and the `AtomFeed` class it contains.
* Changes to `Context`:
  * Removed `Context#post`, `Context#delete`, and `Context#get`. Replaced
  them all with `Context#request` (which takes a structured specification of
  the resource) and `Context#request_by_url` (which takes an already
  constructed URL to the resource).
  * Removed the methods `Context#fullpath`, `Context#init_default`, 
    `Context#url`, `Context#create_resource`, `Context#check_for_error_return`,
    `Context#build_stream`, `Context#handle_key`, `Context#flatten_params`, 
    and `Context#flatten_params_array` since simplification of the request
    infrastructure made them unnecessary.
  * Renamed `Context#protocol` to `Context#scheme` to match correct naming in RFC.
* Removed the `parse` method from `Service`, since it didn't actually parse
  the response in any useful way.
* Changes to naming of the configuration endpoints:
  * `ConfCollection` renamed to `ConfigurationFile` (and **conf_collection.rb** 
  renamed to **configuration_file.rb**).
  * `Conf` renamed to `Stanza` (and **conf.rb** renamed to **stanza.rb**).
* `Index#submit` and `Index#attach` now take hash arguments instead of positional
  arguments.
* `Job#setttl` renamed to `Job#set_ttl`.
* `Job#setpriority` renamed to `Job#set_priority`.
* `Job#disable_preview` removed, since a working test scenario couldn't be found
  for it.
* `Collection`'s constructor arguments have changed.
* `Entity`'s constructor arguments have changed.
* `SplunkError` has been removed, and `SplunkHTTPError` has been made a direct
  subclass of `StandardError`.
* Deleted `SearchResults`, since it was superseded by `ResultsReader`.
* The metaprogramming to allow fetching entries of a `Hash` via dot notation has
  been removed. That is, `hash.key` is no longer a synonym for `hash["key"]`.
* The `urlencode` method previously monkeypatched onto `Hash` has been removed.
* `Service#create_collection` was removed.

### New features and APIs

* New examples in the **/examples** directory, showing how to:
  * connect to Splunk
  * manage entities in Splunk
  * run searches and fetch their results from Splunk
  * write data into Splunk
* The whole SDK now handles namespaces properly, and namespaces are first class
  objects. See the header comments of **namespace.rb** for a detailed description
  of Splunk namespaces and their representation in this SDK.
* All XML handling is shimmed to work with either Nokogiri or REXML. It tries
  Nokogiri first, which can process XML vastly faster, and falls back to REXML,
  which will be present in all Ruby installs. The user may all call
  `require_xml_library` to force the SDK to use a Nokogiri or REXML. See
  **xml_shim.rb** for all this behavior.
* Added documentation throughout the SDK.
* The unit testing suite has been completely rewritten and expanded.
* Added a `ResultsReader` class to parse and iterate over sets of XML results from
  search jobs.
* Added methods to `Context`:
  * `host`
  * `port`
  * `token`
  * `username`
  * `password`
  * `namespace`
  * `server_accepting_connections?`
* `Context#restart` takes an optional timeout, and properly handles waiting for
  Splunk to restart.
* Added convenience methods to `Service` to create searches:
  * `create_oneshot`
  * `create_search`
  * `create_stream`
* Added methods to `Service`:
  * `splunk_version`
  * `saved_searches`
* New features added to `Collection`:
  * `Collection#each`, when called without a block, now returns an enumerator over
    all elements in the collection.
  * Added an optional _namespace_ argument to `Collection#delete` and
    `Collection#fetch` so entities can be specified uniquely even in the presence
    of name collisions.
  * Added new methods to `Collection`, mostly designed to recapitulate the
    relevant methods of `Hash`. In the notation below, synonym sets are separated
    by slashes, and names in a set of synonyms that already existed are
    surrounded by square brackets:
    * `[contains?]/has_key?/include?/key?/member?`
    * `[list]/values/to_a`
    * `each_key`
    * `each_pair`
    * `empty?`
    * `entity_class`
    * `fetch/[ [] ]`
    * `keys`
    * `length`
    * `resource`
    * `service`
* Added methods to `Entity`. In the notation below, synonym sets are separated
  by slashes, and names in a set of synonyms that already existed are
  surrounded by square brackets:
  * `content`
  * `delete`
  * `fetch/[ [] ]`
  * `links`
  * `namespace`
  * `refresh`
  * `resource`
  * `service`
* Entities now cache their state. To update the cache, call the entity's `refresh`
  method.
* `Index#clean` takes a timeout instead of waiting forever. If no timeout is
  specified, a default value will be used.
* Added new methods to `Job`. In the notation below, synonym sets are separated
  by slashes, and names in a set of synonyms that already existed are
  surrounded by square brackets:
  * `control`
  * `is_done?`
  * `is_ready?`
  * `sid`
* Added saved search support, accessible via `Service#saved_searches`. `SavedSearch`
  entities have the following additional methods beyond `Entity`:
  * `dispatch`
  * `history`
* Added the following methods to `Stanza` (was: `Conf`). In the notation below, synonym sets are separated by slashes, and names in a set of synonyms that already existed are surrounded by square brackets:
  * `length`
  * `update/[submit]`
* Added new custom exceptions:
  * `AmbiguousEntityReference`, for when a fetch of an entity by name would
    return multiple entities due to name collisions.
  * `EntityNotReady`, raised when a program tries to fetch the state of an entity
    which is queued for creation, but not yet created, such as a search job that
    is not yet ready.
  * `IllegalOperation`, raised by a program when an operation known statically not
    to work, such as deleting an index on Splunk 4.x, is called.

### Architectural changes

* `Job` is now a subclass of `Entity`.
* `Service` is now a subclass of `Context` instead of including the `Context` as
  an instance variable. 
* Removed dependence of `Context` (and the SDK) on the libraries `netrc`, `pathname`,
  and `rest-client`. Now it uses only the standard library plus (optionally)
  Nokogiri.
* Reorganized directory structure of the SDK.
  * The contents of `lib/splunk-sdk-ruby/client/` have been moved to
    `lib/splunk-sdk-ruby`, and **client.rb** has been deleted.
  * **jobs.rb** was moved to `lib/splunk-sdk-ruby/collection/`
  * **job.rb** was moved to `lib/splunk-sdk-ruby/entity/`
* Made all unit test filenames start with **test_** instead of **tc_**.


