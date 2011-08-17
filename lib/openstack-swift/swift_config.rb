# -*- coding: UTF-8 -*-
module Openstack
  module SwiftConfig
    extend self

    def [](name)
      configs[name]
    end

    module_function
    def configs
      @config_file ||= load_file
    end

    def load_file
      YAML.load_file(File.expand_path(File.dirname(__FILE__)) + "/../../config/swift.yml")[:swift]
    end
  end
end
