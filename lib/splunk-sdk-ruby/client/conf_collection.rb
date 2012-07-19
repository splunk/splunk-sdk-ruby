module Splunk
 # A Collection of Conf objects
  class ConfCollection < Collection
    def initialize(svc, conf)
      item = Proc.new do |service, stanza|
        Conf.new(service, _path_stanza(conf, stanza), stanza)
      end
      ctor = Proc.new do |service, stanza, args|
        new_args = args
        new_args[:name] = stanza
        service.context.post(PATH_CONF % conf, new_args)
      end
      dtor = Proc.new do |service, stanza|
        service.context.delete(_path_stanza(conf, stanza))
      end
      super(
        svc, PATH_CONF % [conf, conf], conf, :item => item, :ctor => ctor,
        :dtor => dtor)
    end
  end
end
