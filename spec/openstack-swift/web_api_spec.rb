require "openstack-swift"

URL = "https://sw:8080/auth/v1.0"
USER = "system:root"
PASS = "testpass"

describe Openstack::Swift::WebApi do
  context "when authenticating" do
    it "should authenticate on swift" do
      expect {
        subject.auth(URL, USER, PASS)
      }.to_not raise_error Openstack::Swift::UnauthorizedError
    end

    it "should raise error for a invalid user" do
      expect {
        subject.auth(URL, "system:weirduser", PASS)
      }.to raise_error Openstack::Swift::UnauthorizedError
    end

    it "should return storage-url, storage-token and auth-token" do
      subject.auth(URL, USER, PASS).should have(3).items
    end
  end

  context "when authenticated" do
    before do
      @url, _, @token = subject.auth(URL, USER, PASS)
    end

    it "should return account's details" do
      subject.account(@url, @token).should have_key("bytes_used")
      subject.account(@url, @token).should have_key("object_count")
      subject.account(@url, @token).should have_key("container_count")
    end

    it "should return a list of containers" do
      subject.containers(@url, @token).should be_a(Array)
    end

    it "should return a list of objects" do
      subject.objects(@url, @token, "morellon", :delimiter => "/").should be_a(Array)
    end

    it "should download an object" do
      subject.download_object(@url, @token, "morellon", "Gemfile").should == "/tmp/swift/morellon/Gemfile"
    end

    it "should upload an object" do
      File.open("/tmp/swift-dummy", "w") {|f| f.puts "test file"}
      subject.upload_object(@url, @token, "morellon", "/tmp/swift-dummy").code.should == "201"
    end
  end
end
