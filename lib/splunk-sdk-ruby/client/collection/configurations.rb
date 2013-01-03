require_relative '../collection'
require_relative 'configuration_file'

module Splunk
  PATH_CONFS = ["properties"]

  class Configurations < Collection
    def initialize(service)
      super(service, PATH_CONFS, entity_class=ConfigurationFile)
    end

    def atom_entry_to_entity(entry)
      name = entry["title"]
      return ConfigurationFile.new(@service, name)
    end

    def create(name)
      # Don't bother catching the response. It either succeeds and returns
      # an empty body, or fails and throws a SplunkHTTPError.
      @service.request({:method => :POST,
                        :resource => PATH_CONFS,
                        :body => {"__conf" => name}})
      return ConfigurationFile.new(@service, name)
    end

    def delete(name)
      raise IllegalOperation.new("Cannot delete configuration files from" +
                                     " the REST API.")
    end

    def fetch(name)
      begin
        # Make a request to the server to see if _name_ exists.
        # We don't actually use any information returned from the server
        # besides the status code.
        request_args = {:resource => PATH_CONFS + [name]}
        request_args[:namespace] = namespace if !namespace.nil?
        @service.request(request_args)

        return ConfigurationFile.new(@service, name)
      rescue SplunkHTTPError => err
        if err.code == 404
          return nil
        else
          raise err
        end
      end
    end
  end

end