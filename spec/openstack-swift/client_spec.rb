# -*- coding: UTF-8 -*-
require "openstack-swift"

URL = "https://sw:8080/auth/v1.0"
USER = "system:root"
PASS = "testpass"

describe Openstack::Swift::Client do
  context "when authenticating" do
    it "should return authentication error if one of the parameters is incorrect" do
      expect {
        subject.authenticate("http://incorrect.com/swift", USER, PASS)
      }.to raise_error(Openstack::Swift::AuthenticationError)
    end

    it "shoud not need to authenticate again" do
      expect {
        subject.authenticate(URL, USER, PASS)
        subject.account_info
      }.to_not raise_error
    end
  end
end
