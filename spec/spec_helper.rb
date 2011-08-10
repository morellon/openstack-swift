require "rubygems"
require "bundler/setup"

require "openstack-swift"

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|file| require file}

RSpec.configure do |config|
end
