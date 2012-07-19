module Splunk
# Message objects represent system-wide messages
  class Message < Entity
    def initialize(service, name)
      super(service, PATH_MESSAGES + '/' + name, name)
    end

    # Return the message
    #
    # ==== Returns
    # The message String: (the value of the message named <b>+name+</b>)
    def value
      self[@name]
    end
  end
end
