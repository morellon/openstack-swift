# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "openstack-swift/version"

Gem::Specification.new do |s|
  s.name        = "openstack-swift"
  s.version     = Openstack::Swift::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["morellon", "pothix"]
  s.email       = ["morellon@gmail.com", "pothix@pothix.com"]
  s.homepage    = "http://github.com/morellon/openstack-swift"
  s.description = %q{Openstack's swift client}
  s.summary     = s.description

  s.rubyforge_project = "openstack-swift"

  s.files         = Dir["./**/*"].reject {|file| file =~ /\.git|pkg/}
  s.require_paths = ["lib"]

  s.add_dependency "httparty"
  s.add_development_dependency "rspec", "~> 2.6"
  s.add_development_dependency "ruby-debug19"
end
