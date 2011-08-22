# -*- coding: UTF-8 -*-
require "spec_helper"

describe "Openstack::Swift::Client" do
  let!(:swift_dummy_file) do
    file_path = "/tmp/swift-dummy"
    File.open(file_path, "w") {|f| f.puts("testfile "*1000)}
    file_path
  end

  context "when authenticating" do
    it "should return authentication error if one of the parameters is incorrect" do
      expect {
        Openstack::Swift::Client.new("http://incorrect.com/swift", Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass])
      }.to raise_error(Openstack::Swift::AuthenticationError)
    end

    it "shoud not need to authenticate again" do
      client = Openstack::Swift::Client.new(Openstack::SwiftConfig[:url], Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass])
      Openstack::Swift::Api.should_not_receive(:auth)
      client.account_info
    end
  end

  context "when authenticated" do
    subject { Openstack::Swift::Client.new(Openstack::SwiftConfig[:url], Openstack::SwiftConfig[:user], Openstack::SwiftConfig[:pass]) }

    it "should upload a splitted file and create its manifest" do
      pending "WTF...Not working for a unknown reason"
      subject.upload("pothix", swift_dummy_file, {:segments_size => 1024*2})
      subject.object_info("pothix", "swifty-dummy")["manifest"].should_not be_nil
    end

    it "should download an splitted file" do
      content_length = subject.object_info("morellon", "splitted_file")["content_length"].to_i
      file_path = subject.download("morellon", "splitted_file")
      File.size(file_path).should == content_length
    end

    it "should return account's details" do
      account_info = subject.account_info
      account_info.should have_key("bytes_used")
      account_info.should have_key("object_count")
      account_info.should have_key("container_count")
    end
  end
end
