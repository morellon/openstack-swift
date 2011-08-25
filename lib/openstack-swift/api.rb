# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    module Api
      extend self
      MAX_SIZE = 4 * 1024 ** 3

      # Authentication method to get the url and token to conect to swift
      # Returns:
      #   x-storage-url
      #   x-storage-token
      #   x-auth-token
      def auth(proxy, user, password)
        res = HTTParty.get(proxy, :headers => {"X-Auth-User" => user, "X-Auth-Key" => password})
        raise AuthenticationError unless res.code == 200

        [res.headers["x-storage-url"],res.headers["x-storage-token"],res.headers["x-auth-token"]]
      end

      # Get informations about the currect account used to connect to swift
      # Returns:
      #   x-account-bytes-used
      #   x-account-object-count
      #   x-account-container-count
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

      # Get all objects for a given container
      # Query options:
      #   marker
      #   prefix
      #   limit
      #   delimiter
      def objects(url, token, container, query = {})
        query = query.merge(:format => "json")
        res = HTTParty.get("#{url}/#{container}", :headers => {"X-Auth-Token"=> token}, :query => query)
        res.to_a
      end

      # Delete a container for a given name from swift
      def delete_container(url, token, container)
        res = HTTParty.delete("#{url}/#{container}", :headers => {"X-Auth-Token"=> token})
        raise "Could not delete container '#{container}'" if res.code < 200 or res.code >= 300
        true
      end

      # Create a container on swift from a given name
      def create_container(url, token, container)
        res = HTTParty.put("#{url}/#{container}", :headers => {"X-Auth-Token"=> token})
        raise "Could not create container '#{container}'" if res.code < 200 or res.code >= 300
        true
      end

      # Get the object stat given the object name and the container this object is in
      def object_stat(url, token, container, object)
        url = "#{url}/#{container}/#{object}"
        query = {:format => "json"}
        HTTParty.head(url, :headers => {"X-Auth-Token"=> token}, :query => query).headers
      end

      # Creates the manifest file for a splitted upload
      # Given the container and file path a manifest is created to guide the downloads of this
      # splitted file
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

      # Delete a object for a given container and object name
      def delete_object(url, token, container, object)
        res = HTTParty.delete("#{url}/#{container}/#{object}", :headers => {"X-Auth-Token"=> token})
        raise "Could not delete object '#{object}'" if res.code < 200 or res.code >= 300
        true
      end

      # Delete all files listed on a manifest following the swift standard order
      # What it does is try to delete all files in sequence from a given manifest until there are no files to delete
      # returning a 404 error code. We don't know how many files are stored for a manifest file.
      def delete_objects_from_manifest(url, token, container, manifest)
        manifest_info = object_stat(url, token, container, manifest)
        files_path = "#{manifest_info["x-object-manifest"]}%08d"

        manifest_info["content-length"].to_i.times do |index|
          res = HTTParty.delete("#{url}/#{files_path % index}", :headers => {"X-Auth-Token"=> token})
          raise ObjectNotFoundError if res.code == 404
        end
      rescue ObjectNotFoundError
        true
      end

      def upload_object(url, token, container, file_path, options={})
        options[:segments_size] ||= MAX_SIZE

        create_container(url, token, container) rescue nil

        file_name, file_mtime, file_size  = file_info(file_path)

        if file_size > options[:segments_size]
          create_container(url, token, "#{container}_segments") rescue nil

          segments_minus_one = file_size / options[:segments_size]
          last_piece = file_size - segments_minus_one * options[:segments_size]
          segments_minus_one.times do |segment|
            upload_segment(
              url, token, "#{container}_segments", file_path,
              :size => options[:segments_size],
              :position => options[:segments_size] * segment,
              :object_name => upload_path_for(file_path, segment)
            )
          end

          upload_segment(
            url, token, "#{container}_segments", file_path,
            :size => last_piece,
            :position => options[:segments_size] * segments_minus_one,
            :object_name => upload_path_for(file_path, segments_minus_one)
          )

          create_manifest(url, token, container, file_path)
        else
          upload_segment(url, token, container, file_path)
        end
      end

      # Uploads a given object to a given container
      def upload_segment(url, token, container, file_path, options={})
        options[:object_name] ||= file_path.match(/.+\/(.+?)$/)[1]
        file = File.open(file_path, "rb")

        file.seek(options[:position]) if options[:position]
        uri = URI.parse("#{url}/#{container}/#{options[:object_name]}")

        req = Net::HTTP::Put.new(uri.path)
        req.add_field("X-Auth-Token", token)
        req.body_stream = file
        req.content_length = options[:size] || File.size(file_path)
        req.content_type = "application/octet-stream"

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.request(req)
      ensure
        file.close rescue nil
      end

      private
      # Returns the standard swift path for a given file path and segment
      def upload_path_for(file_path, segment)
       "%s/%s/%s/%08d" % (file_info(file_path) << segment)
      end

      # Get relevant informations about a file
      # Returns an array with:
      #   file_name
      #   file_mtime
      #   file_size
      def file_info(file_path)
       [
         file_path.match(/.+\/(.+?)$/)[1],
         File.mtime(file_path).to_f.round(2),
         File.size(file_path)
       ]
      end
    end
  end
end
