require "rubygems"
require "bundler/setup"

class SplunkError < StandardError
  def initialize(msg)
    super msg
  end
end