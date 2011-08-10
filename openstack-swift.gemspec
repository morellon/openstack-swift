# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "openstack-swift/version"

Gem::Specification.new do |s|
  s.name        = "openstack-swift"
  s.version     = Openstack::Swift::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["morellon", "pothix"]
  s.email       = ["morellon@gmail.com", "pothix@pothix.com"]
  s.homepage    = ""
  s.summary     = %q{Openstack's swift client}
  s.description = %q{Openstack's swift client}

  s.rubyforge_project = "openstack-swift"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end
