# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    module WebApi
      extend self

      def auth(proxy, user, password)
        res = HTTParty.get(proxy, :headers => {"X-Auth-User" => user, "X-Auth-Key" => password})
        raise AuthenticationError unless res.code == 200

        [res.headers["x-storage-url"],res.headers["x-storage-token"],res.headers["x-auth-token"]]
      end

      def account(url, token)
        query = {:format => "json"}
        HTTParty.head(url, :headers => {"X-Auth-Token"=> token}, :query => query).headers
      end

      # List containers
      # Note that swift only returns 1000 items, so to list more than this
      # you should use the marker option as the name of the last returned item (1000th item)
      # to return the next sequency (1001 - 2000)
      # query options: marker, prefix, limit
      def containers(url, token, query = {})
        query = query.merge(:format => "json")
        res = HTTParty.get(url, :headers => {"X-Auth-Token"=> token}, :query => query)
        res.to_a
      end

      # query options: marker, prefix, limit, delimiter
      def objects(url, token, container, query = {})
        query = query.merge(:format => "json")
        res = HTTParty.get("#{url}/#{container}", :headers => {"X-Auth-Token"=> token}, :query => query)
        res.to_a
      end

      def delete_container(url, token, container)
        res = HTTParty.delete("#{url}/#{container}", :headers => {"X-Auth-Token"=> token})
        raise "Could not delete container '#{container}'" if res.code < 200 or res.code >= 300
        true
      end

      def create_container(url, token, container)
        res = HTTParty.put("#{url}/#{container}", :headers => {"X-Auth-Token"=> token})
        raise "Could not create container '#{container}'" if res.code < 200 or res.code >= 300
        true
      end

      def object_stat(url, token, container, object)
        url = "#{url}/#{container}/#{object}"
        query = {:format => "json"}
        HTTParty.head(url, :headers => {"X-Auth-Token"=> token}, :query => query).headers
      end

      def create_manifest(url, token, container, file_path)
        file_name = file_path.match(/.+\/(.+?)$/)[1]
        file_size  = File.size(file_path)
        file_mtime = File.mtime(file_path).to_f.round(2)
        manifest_path = "#{container}_segments/#{file_name}/#{file_mtime}/#{file_size}/"

        res = HTTParty.put("#{url}/#{container}/#{file_name}", :headers => {
          "X-Auth-Token" => token,
          "x-object-manifest" => manifest_path,
          "Content-Type" => "application/octet-stream",
          "Content-Length" => "0"
        })

        raise "Could not create manifest for '#{file_path}'" if res.code < 200 or res.code >= 300
        true
      end

      # Downloads an object (file) to disk and returns the saved file path
      def download_object(url, token, container, object, file_name=nil)
        file_name ||= "/tmp/swift/#{container}/#{object}"

        # creating directory if it doesn't exist
        FileUtils.mkdir_p(file_name.match(/(.+)\/.+?$/)[1])
        file = File.open(file_name, "wb")
        uri = URI.parse("#{url}/#{container}/#{object}")

        req = Net::HTTP::Get.new(uri.path)
        req.add_field("X-Auth-Token", token)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        md5 = Digest::MD5.new

        http.request(req) do |res|
          res.read_body do |chunk|
            file.write chunk
            md5.update(chunk)
          end

          raise "MD5 checksum failed for #{container}/#{object}" if res["x-object-manifest"].nil? && res["etag"] != md5.hexdigest
        end

        file_name
      ensure
        file.close rescue nil
      end

      # Uploads a given object to a given container
      def upload_object(url, token, container, file_path, position = nil, size = nil, object_name=nil)
        object_name ||= file_path.match(/.+\/(.+?)$/)[1]
        file = File.open(file_path, "rb")

        file.seek(position) if position
        uri = URI.parse("#{url}/#{container}/#{object_name}")

        req = Net::HTTP::Put.new(uri.path)
        req.add_field("X-Auth-Token", token)
        req.body_stream = file
        req.content_length = size || File.size(file_path)
        req.content_type = "application/octet-stream"

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.request(req)
      ensure
        file.close rescue nil
      end
    end
  end
end
