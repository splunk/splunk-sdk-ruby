module Splunk
  class SearchResults
    include Enumerable

    def initialize(data)
      @data = data
    end

    def each(&block)
      @data.each {|row| block.call(row) }
    end
  end
end
