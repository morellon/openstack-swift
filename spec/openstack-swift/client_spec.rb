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

    it "should try to upload" do
      expect {
        subject.upload("pothix", swift_dummy_file, {:segments_size => 1024*2})
      }.to_not raise_error
      subject.object_info("pothix", "swift-dummy")["manifest"].should_not be_nil
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

    context "when deleting" do
      it "should call the delete method for a non manifest file" do
        Openstack::Swift::Api.should_receive(:object_stat).and_return({"x-object-manifest" => nil})
        Openstack::Swift::Api.should_receive(:delete_object)
        subject.delete("pothix","swift-dummy")
      end

      it "should call the delete_objects_from_manifest method for a manifest file" do
        Openstack::Swift::Api.should_receive(:object_stat).and_return({"x-object-manifest" => "pothix_segments/swift-dummy/1313763802.0/9001/"})
        Openstack::Swift::Api.should_receive(:delete_objects_from_manifest)
        subject.delete("pothix","swift-dummy")
      end
    end
  end
end
