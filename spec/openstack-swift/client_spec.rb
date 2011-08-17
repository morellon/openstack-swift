# -*- coding: UTF-8 -*-
require "spec_helper"

describe Openstack::Swift::Client do
  context "when authenticating" do
    it "should return authentication error if one of the parameters is incorrect" do
      expect {
        subject.authenticate("http://incorrect.com/swift", Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass])
      }.to raise_error(Openstack::Swift::AuthenticationError)
    end

    it "shoud not need to authenticate again" do
      expect {
        subject.authenticate(Openstack::SwiftConfig[:url], Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass])
        subject.account_info
      }.to_not raise_error
    end
  end
end
