module Splunk
# Message objects represent system-wide messages
  class Message < Entity
    def initialize(service, namespace, resource, name, state=nil)
      super(service, namespace, resource, name, state)
      refresh()
    end

    # Return the message
    #
    # ==== Returns
    # The message String: (the value of the message named <b>+name+</b>)
    def value
      fetch(@name)
    end
  end
end
