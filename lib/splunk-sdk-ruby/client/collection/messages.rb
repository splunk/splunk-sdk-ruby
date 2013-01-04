module Splunk
  class Messages < Collection
    def create(name, args)
      body_args = args.clone()
      body_args["name"] = name

      request_args = {
          :method => :POST,
          :resource => @resource,
          :body => body_args
      }
      if args.has_key?(:namespace)
        request_args[:namespace] = body_args.delete(:namespace)
      end

      response = @service.request(request_args)
      entity = Message.new(@service, namespace("system"),
                           @resource, name)
      return entity
    end

  end
end
