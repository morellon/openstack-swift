# -*- coding: UTF-8 -*-
require "rubygems"
require "bundler/setup"

require "openstack-swift"

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|file| require file}

# Using a diferent YAML engine on test environment
YAML::ENGINE::yamler = "syck"

RSpec.configure do |config|
end
