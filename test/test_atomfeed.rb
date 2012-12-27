require_relative "test_helper"
require "splunk-sdk-ruby"

# URI's classes compare by object identity, which is exactly what we
# *don't* want to do. Instead we use simple textual identity.
module URI
  class Generic
    def ==(other)
      return self.to_s == other.to_s
    end
  end

  class HTTPS
    def ==(other)
      return self.to_s == other.to_s
    end
  end

  class HTTP
    def ==(other)
      return self.to_s == other.to_s
    end
  end
end

class TestAtomFeed < Test::Unit::TestCase
  def test_feeds
    # If Nokogiri is available, we'll test AtomFeed against both it
    # and REXML. Otherwise, we'll print a warning and test only against
    # REXML. REXML is part of the standard library in Ruby 1.9, so it will
    # always be present.
    begin
      require 'nokogiri'
      xml_libraries = [:nokogiri, :rexml]
    rescue LoadError
      xml_libraries = [:rexml]
      puts "Nokogiri not installed. Skipping."
    end

    xml_libraries.each do |xml_library|
      $tests.each_entry do |filename, expected|
        puts "#{xml_library}: #{filename}"
        file = File.open(filename)
        feed = Splunk::AtomFeed.new(file, xml_library=xml_library)

        # To make debugging easy, test the metadata a key at
        # a time, since Test::Unit doesn't display diffs.
        # Then test the whole thing at the end to make sure it all matches.
        expected[:metadata].each_entry do |key, value|
          assert_equal([filename, key, value],
                       [filename, key, feed.metadata[key]])
        end
        assert_equal(expected[:metadata], feed.metadata)

        # To make debugging easy, test each key of each entry
        # separately, since Test::Unit doesn't display diffs.
        # Then test the whole thing at the end to make sure it all matches.
        expected[:entries].each_with_index do |entry, index|
          entry.each_entry do |key, value|
            assert_equal([filename, index, key, value],
                         [filename, index, key, feed.entries[index][key]])
          end
        end
        assert_equal(expected[:entries], feed.entries)
      end
    end
  end
end

$tests = {
    'test/data/atom/atom_with_feed.xml' => {
        :metadata => {
            "title" => "localapps",
            "id" => URI("https://localhost:8089/servicesNS/nobody/system/apps/local"),
            "updated" => "2012-12-19T11:07:48-08:00",
            "generator" => {"build" => "144175", "version" => "5.0.2"},
            "author" => "Splunk",
            "links" => {
                "create" => URI("/servicesNS/nobody/system/apps/local/_new"),
                "_reload" => URI("/servicesNS/nobody/system/apps/local/_reload")
            },
            "totalResults" => "1",
            "itemsPerPage" => "30",
            "startIndex" => "0",
            "messages" => []
        },
        :entries => [
            {
                "title" => "gettingstarted",
                "id" => URI("https://localhost:8089/servicesNS/nobody/system/apps/local/gettingstarted"),
                "updated" => "2012-12-19T11:07:48-08:00",
                "author" => "nobody",
                "links" => {
                    "alternate" => URI("/servicesNS/nobody/system/apps/local/gettingstarted"),
                    "list" => URI("/servicesNS/nobody/system/apps/local/gettingstarted"),
                    "_reload" => URI("/servicesNS/nobody/system/apps/local/gettingstarted/_reload"),
                    "edit" => URI("/servicesNS/nobody/system/apps/local/gettingstarted"),
                    "remove" => URI("/servicesNS/nobody/system/apps/local/gettingstarted"),
                    "disable" => URI("/servicesNS/nobody/system/apps/local/gettingstarted/disable"),
                    "package" => URI("/servicesNS/nobody/system/apps/local/gettingstarted/package")
                },
                "content" => {
                    "author" => "Splunk",
                    "check_for_updates" => "1",
                    "configured" => "1",
                    "description" => "Get started with Splunk.  This app introduces you to many of Splunk's features.  You'll learn how to use Splunk to index data, search and investigate, add knowledge, monitor and alert, report and analyze.",
                    "disabled" => "0",
                    "eai:acl" => {
                        "app" => "system",
                        "can_change_perms" => "1",
                        "can_list" => "1",
                        "can_share_app" => "1",
                        "can_share_global" => "1",
                        "can_share_user" => "0",
                        "can_write" => "1",
                        "modifiable" => "1",
                        "owner" => "nobody",
                        "perms" => {
                            "read" => ["*"],
                            "write" => ["power"]
                        },
                        "removable" => "0",
                        "sharing" => "app"
                    },
                    "eai:attributes" => {
                        "optionalFields" => ["author", "check_for_updates",
                                             "configured", "description",
                                             "label", "manageable", "version",
                                             "visible"],
                        "requiredFields" => [],
                        "wildcardFields" => []
                    },
                    "label" => "Getting started",
                    "manageable" => "1",
                    "state_change_requires_restart" => "0",
                    "version" => "1.0",
                    "visible" => "1"
                }
            }
        ]
    },
    'test/data/atom/atom_without_feed.xml' => {
        :metadata => {},
        :entries => [
            {
                "title" => "| metadata type=sources | search totalCount>0 | " +
                    "rename totalCount as Count recentTime as \"Last Update\" | " +
                    "table source Count \"Last Update\" | fieldformat " +
                    "Count=tostring(Count, \"commas\") | fieldformat " +
                    "\"Last Update\"=strftime('Last Update', \"%c\")",
                "id" => URI("https://localhost:8089/services/search/jobs/rt_1355944187.129"),
                "updated" => "2012-12-19T11:09:52.000-08:00",
                "published" => "2012-12-19T11:09:47.000-08:00",
                "links" => {
                    "alternate" => URI("/services/search/jobs/rt_1355944187.129"),
                    "search.log" => URI("/services/search/jobs/rt_1355944187.129/search.log"),
                    "events" => URI("/services/search/jobs/rt_1355944187.129/events"),
                    "results" => URI("/services/search/jobs/rt_1355944187.129/results"),
                    "results_preview" => URI("/services/search/jobs/rt_1355944187.129/results_preview"),
                    "timeline" => URI("/services/search/jobs/rt_1355944187.129/timeline"),
                    "summary" => URI("/services/search/jobs/rt_1355944187.129/summary"),
                    "control" => URI("/services/search/jobs/rt_1355944187.129/control")
                },
                "author" => "admin",
                "content" => {
                    "cursorTime" => "1969-12-31T16:00:00.000-08:00",
                    "delegate" => "",
                    "diskUsage" => "49152",
                    "dispatchState" => "RUNNING",
                    "doneProgress" => "1.00000",
                    "dropCount" => "0",
                    "earliestTime" => "1969-12-31T16:00:00.000-08:00",
                    "eventAvailableCount" => "0",
                    "eventCount" => "0",
                    "eventFieldCount" => "0",
                    "eventIsStreaming" => "1",
                    "eventIsTruncated" => "1",
                    "eventSearch" => "",
                    "eventSorting" => "none",
                    "isDone" => "0",
                    "isFailed" => "0",
                    "isFinalized" => "0",
                    "isPaused" => "0",
                    "isPreviewEnabled" => "1",
                    "isRealTimeSearch" => "1",
                    "isRemoteTimeline" => "0",
                    "isSaved" => "0",
                    "isSavedSearch" => "0",
                    "isZombie" => "0",
                    "keywords" => "",
                    "label" => "",
                    "latestTime" => "1969-12-31T16:00:00.000-08:00",
                    "meanPreviewPeriod" => "1.708000",
                    "numPreviews" => "3",
                    "pid" => "11902",
                    "priority" => "5",
                    "remoteSearch" => "metadata  gather=false type=sources  update_period=0",
                    "reportSearch" => "metadata  type=sources  | search totalCount>0 " +
                        " | rename  totalCount as Count recentTime as \"Last Update\" " +
                        " | table  source Count \"Last Update\" ",
                    "resultCount" => "0",
                    "resultIsStreaming" => "0",
                    "resultPreviewCount" => "5",
                    "runDuration" => "5.124000",
                    "scanCount" => "0",
                    "sid" => "rt_1355944187.129",
                    "statusBuckets" => "0",
                    "ttl" => "599",
                    "performance" => {
                        "command.metadata" => {
                            "duration_secs" => "4.995000",
                            "invocations" => "9",
                            "input_count" => "0",
                            "output_count" => "6"
                        },
                        "command.metadata.execute_input" => {
                            "duration_secs" => "0.009000",
                            "invocations" => "9"
                        },
                        "dispatch.check_disk_usage" => {
                            "duration_secs" => "0.001000",
                            "invocations" => "1"
                        },
                        "dispatch.createProviderQueue" => {
                            "duration_secs" => "0.005000",
                            "invocations" => "1"
                        },
                        "dispatch.evaluate" => {
                            "duration_secs" => "0.028000",
                            "invocations" => "1"
                        },
                        "dispatch.evaluate.fieldformat" => {
                            "duration_secs" => "0.002000",
                            "invocations" => "2"
                        },
                        "dispatch.evaluate.metadata" => {
                            "duration_secs" => "0.003000",
                            "invocations" => "1"
                        },
                        "dispatch.evaluate.rename" => {
                            "duration_secs" => "0.001000",
                            "invocations" => "1"
                        },
                        "dispatch.evaluate.search" => {
                            "duration_secs" => "0.021000",
                            "invocations" => "1"
                        },
                        "dispatch.evaluate.table" => {
                            "duration_secs" => "0.001000",
                            "invocations" => "1"
                        },
                        "dispatch.fetch" => {
                            "duration_secs" => "4.996000",
                            "invocations" => "9"
                        },
                        "dispatch.preview" => {
                            "duration_secs" => "0.088000",
                            "invocations" => "3"
                        },
                        "dispatch.preview.command.rename" => {
                            "duration_secs" => "0.004000",
                            "invocations" => "3",
                            "input_count" => "15",
                            "output_count" => "15",
                        },
                        "dispatch.preview.command.search" => {
                            "duration_secs" => "0.057000",
                            "invocations" => "3",
                            "input_count" => "15",
                            "output_count" => "15"
                        },
                        "dispatch.preview.command.search.filter" => {
                            "duration_secs" => "0.003000",
                            "invocations" => "3"
                        },
                        "dispatch.preview.command.table" => {
                            "duration_secs" => "0.013000",
                            "invocations" => "3",
                            "input_count" => "15",
                            "output_count" => "30"
                        },
                        "dispatch.preview.metadata.execute_output" => {
                            "duration_secs" => "0.003000",
                            "invocations" => "3"
                        },
                        "dispatch.preview.write_results_to_disk" => {
                            "duration_secs" => "0.015000",
                            "invocations" => "3"
                        },
                        "dispatch.stream.local" => {
                            "duration_secs" => "4.996000",
                            "invocations" => "9"
                        },
                        "dispatch.writeStatus" => {
                            "duration_secs" => "0.013000",
                            "invocations" => "6"
                        },
                        "startup.handoff" => {
                            "duration_secs" => "0.138000",
                            "invocations" => "1"
                        }
                    },
                    "messages" => {},
                    "request" => {
                        "auto_cancel" => "90",
                        "earliest_time" => "rt",
                        "latest_time" => "rt",
                        "max_count" => "100000",
                        "search" => "| metadata type=sources | search totalCount>0 " +
                            "| rename totalCount as Count recentTime as \"Last Update\"" +
                            " | table source Count \"Last Update\" | fieldformat" +
                            " Count=tostring(Count, \"commas\") | fieldformat" +
                            " \"Last Update\"=strftime('Last Update', \"%c\")",
                        "status_buckets" => "0",
                        "time_format" => "%s.%Q",
                        "ui_dispatch_app" => "search",
                        "ui_dispatch_view" => "dashboard_live"
                    },
                    "eai:acl" => {
                        "perms" => {
                            "read" => ["admin"],
                            "write" => ["admin"],
                        },
                        "owner" => "admin",
                        "modifiable" => "1",
                        "sharing" => "global",
                        "app" => "search",
                        "can_write" => "1"
                    },
                    "searchProviders" => ["fross-mbp15.local"],
                }
            }
        ]
    },
    'test/data/atom/atom_with_several_entries.xml' => {
        :metadata => {
            "title" => "localapps",
            "id" => URI("https://localhost:8089/services/apps/local"),
            "updated" => "2012-12-19T15:27:58-08:00",
            "generator" => {"version" => "140437"},
            "author" => "Splunk",
            "links" => {
                "create" => URI("/services/apps/local/_new"),
                "_reload" => URI("/services/apps/local/_reload")
            },
            "totalResults" => "12",
            "itemsPerPage" => "30",
            "startIndex" => "0",
            "messages" => []
        },
        :entries => [
            {
                "title" => "gettingstarted",
                "id" => URI("https://localhost:8089/services/apps/local/gettingstarted"),
                "updated" => "2012-12-19T15:27:58-08:00",
                "author" => "system",
                "links" => {
                    "alternate" => URI("/services/apps/local/gettingstarted"),
                    "list" => URI("/services/apps/local/gettingstarted"),
                    "_reload" => URI("/services/apps/local/gettingstarted/_reload"),
                    "edit" => URI("/services/apps/local/gettingstarted"),
                    "remove" => URI("/services/apps/local/gettingstarted"),
                    "disable" => URI("/services/apps/local/gettingstarted/disable"),
                    "package" => URI("/services/apps/local/gettingstarted/package")
                },
                "content" => {
                    "author" => "Splunk",
                    "check_for_updates" => "1",
                    "configured" => "1",
                    "description" => "Get started with Splunk.  This app " +
                        "introduces you to many of Splunk's features.  You'll " +
                        "learn how to use Splunk to index data, search and " +
                        "investigate, add knowledge, monitor and alert, report " +
                        "and analyze.",
                    "disabled" => "0",
                    "eai:acl" => {
                        "app" => "",
                        "can_change_perms" => "1",
                        "can_list" => "1",
                        "can_share_app" => "1",
                        "can_share_global" => "1",
                        "can_share_user" => "0",
                        "can_write" => "1",
                        "modifiable" => "1",
                        "owner" => "system",
                        "perms" => {
                            "read" => ["*"],
                            "write" => ["power"]
                        },
                        "removable" => "0",
                        "sharing" => "app",
                    },
                    "label" => "Getting started",
                    "manageable" => "0",
                    "state_change_requires_restart" => "0",
                    "version" => "1.0",
                    "visible" => "1"
                }
            },

            {
                "title" => "launcher",
                "id" => URI("https://localhost:8089/services/apps/local/launcher"),
                "updated" => "2012-12-19T15:27:58-08:00",
                "author" => "system",
                "links" => {
                    "alternate" => URI("/services/apps/local/launcher"),
                    "list" => URI("/services/apps/local/launcher"),
                    "_reload" => URI("/services/apps/local/launcher/_reload"),
                    "edit" => URI("/services/apps/local/launcher"),
                    "remove" => URI("/services/apps/local/launcher"),
                    "package" => URI("/services/apps/local/launcher/package")
                },
                "content" => {
                    "check_for_updates" => "1",
                    "configured" => "1",
                    "disabled" => "0",
                    "eai:acl" => {
                        "app" => "",
                        "can_change_perms" => "1",
                        "can_list" => "1",
                        "can_share_app" => "1",
                        "can_share_global" => "1",
                        "can_share_user" => "0",
                        "can_write" => "1",
                        "modifiable" => "1",
                        "owner" => "system",
                        "perms" => {
                            "read" => ["*"],
                            "write" => ["power"]
                        },
                        "removable" => "0",
                        "sharing" => "app",
                    },
                    "label" => "Home",
                    "manageable" => "0",
                    "state_change_requires_restart" => "0",
                    "visible" => "1"
                }
            },

            {
                "title" => "learned",
                "id" => URI("https://localhost:8089/services/apps/local/learned"),
                "updated" => "2012-12-19T15:27:58-08:00",
                "author" => "system",
                "links" => {
                    "alternate" => URI("/services/apps/local/learned"),
                    "list" => URI("/services/apps/local/learned"),
                    "_reload" => URI("/services/apps/local/learned/_reload"),
                    "edit" => URI("/services/apps/local/learned"),
                    "remove" => URI("/services/apps/local/learned"),
                    "disable" => URI("/services/apps/local/learned/disable"),
                    "package" => URI("/services/apps/local/learned/package")
                },
                "content" => {
                    "check_for_updates" => "1",
                    "configured" => "0",
                    "disabled" => "0",
                    "eai:acl" => {
                        "app" => "",
                        "can_change_perms" => "1",
                        "can_list" => "1",
                        "can_share_app" => "1",
                        "can_share_global" => "1",
                        "can_share_user" => "0",
                        "can_write" => "1",
                        "modifiable" => "1",
                        "owner" => "system",
                        "perms" => {"read" => ["*"], "write" => ["*"]},
                        "removable" => "0",
                        "sharing" => "app"
                    },
                    "label" => "learned",
                    "manageable" => "1",
                    "state_change_requires_restart" => "0",
                    "visible" => "0"
                }
            }
        ]
    },
    'test/data/atom/atom_with_simple_entries.xml' => {
        :metadata => {
            "title" => "services",
            "id" => URI("https://localhost:8089/services/"),
            "updated" => "2012-12-20T09:48:01-08:00",
            "generator" => {"version" => "140437"},
            "author" => "Splunk",
            "links" => {},
            "messages" => []
        },
        :entries => [
            {
                "title" => "alerts",
                "id" => URI("https://localhost:8089/services/alerts"),
                "updated" => "2012-12-20T09:48:01-08:00",
                "links" => {
                    "alternate" => URI("/services/alerts")
                }
            },
            {
                "title" => "apps",
                "id" => URI("https://localhost:8089/services/apps"),
                "updated" => "2012-12-20T09:48:01-08:00",
                "links" => {
                    "alternate" => URI("/services/apps")
                }
            },
            {
                "title" => "auth",
                "id" => URI("https://localhost:8089/services/auth"),
                "updated" => "2012-12-20T09:48:01-08:00",
                "links" => {
                    "alternate" => URI("/services/auth")
                }
            }
        ]
    }
}
