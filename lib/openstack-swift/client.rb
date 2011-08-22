# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
      SWIFT_API = Openstack::Swift::Api
      MAX_SIZE = 4 * 1024 ** 3

      # Initialize method
      # It uses the authenticate method to store the tokens for future requests
      def initialize(proxy, user, password)
        @proxy, @user, @password = proxy, user, password
        authenticate!
      end

      # Authentication method
      # It stores the authentication url and token for future commands
      # avoiding to request a new token for each request
      # It should be used to force a new token
      def authenticate!
        @url, _, @token = SWIFT_API.auth(@proxy, @user, @password)

        if @url.blank? or @token.blank?
          raise AuthenticationError
        else
          true
        end
      end

      # Returns the following informations about the object:
      #   bytes_used: Number of bytes used by this account
      #   object_count: Number of objects that this account have allocated
      #   container_count: Number of container
      def account_info
        headers = SWIFT_API.account(@url, @token)
        {
          "bytes_used" => headers["x-account-bytes-used"],
          "object_count" => headers["x-account-object-count"],
          "container_count" => headers["x-account-container-count"]
        }
      end

      # Returns the following informations about the account:
      #   last_modified
      #   md5
      #   content_type
      #   manifest
      #   content_length
      def object_info(container, object)
        headers = SWIFT_API.object_stat(@url, @token, container, object)
        {
          "last_modified" => headers["last-modified"],
          "md5" => headers["etag"],
          "content_type" => headers["content-type"],
          "manifest" => headers["x-object-manifest"],
          "content_length" => headers["content-length"]
        }
      end

      # This method uploads a file from a given to a given container
      def upload(container, file_path, options={})
        options[:segments_size] ||= MAX_SIZE

        SWIFT_API.create_container(@url, @token, container) rescue nil

        if File.size(file_path) > options[:segments_size]
          SWIFT_API.create_container(@url, @token, "#{container}_segments") rescue nil
          file_name = file_path.match(/.+\/(.+?)$/)[1]
          file_size  = File.size(file_path)
          file_mtime = File.mtime(file_path).to_f.round(2)

          full_file = File.open(file_path, "rb")
          segments_minus_one = File.size(file_path) / options[:segments_size]
          last_piece = File.size(file_path) - segments_minus_one * options[:segments_size]
          segments_minus_one.times do |i|
            segment_path = "#{file_name}/#{file_mtime}/#{file_size}/%08d" % i
            SWIFT_API.upload_object(
              @url, @token, "#{container}_segments", file_path,
              :size => options[:segments_size],
              :position => options[:segments_size] * i,
              :object_name => segment_path
            )
          end

          segment_path = "#{file_name}/#{file_mtime}/#{file_size}/%08d" % segments_minus_one

          SWIFT_API.upload_object(
            @url, @token, "#{container}_segments", file_path,
            :size => last_piece,
            :position => options[:segments_size] * segments_minus_one,
            :object_name => segment_path
          )

          SWIFT_API.create_manifest(@url, @token, container, file_path)
        else
          SWIFT_API.upload_object(@url, @token, container, file_path)
        end
      ensure
        full_file.close rescue nil
      end

      # This method downloads a object from a given container
      def download(container, object)
        SWIFT_API.download_object(@url, @token, container, object)
      end
    end
  end
end
