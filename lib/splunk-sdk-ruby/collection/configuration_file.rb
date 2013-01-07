require_relative '../collection'

module Splunk
  # ConfigurationFile is a collection containing configuration stanzas.
  #
  class ConfigurationFile < Collection
    # This class is unusual: it is the element of a collection itself,
    # and its elements are entities.

    def initialize(service, name)
      super(service, ["configs", "conf-#{name}"], entity_class=Stanza)
      @name = name
    end

    attr_reader :name
  end
end
