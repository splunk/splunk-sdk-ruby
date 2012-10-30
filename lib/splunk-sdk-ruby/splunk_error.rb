require 'rubygems'

module Splunk
  class SplunkError < StandardError
    def initialize(msg)
      super msg
    end
  end
end
