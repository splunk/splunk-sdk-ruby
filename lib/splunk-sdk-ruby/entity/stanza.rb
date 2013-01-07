module Splunk
  class Stanza < Entity
    #Populate a stanza in the .conf file
    synonym "submit", "update"

    def length()
      @state["content"].
          reject() { |k| k.start_with?("eai") || k == "disabled" }.
          length()
    end
  end

end
