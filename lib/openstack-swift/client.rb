# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
      MAX_SIZE = 4 * 1024 ** 3

      # Authentication method
      # It stores the authentication url and token for future commands
      # Avoiding to request a new token for each request
      def initialize(proxy, user, password)
        @url, _, @token = Openstack::Swift::WebApi.auth(proxy, user, password)

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
        headers = Openstack::Swift::WebApi.account(@url, @token)
        {
          "bytes_used" => headers["x-account-bytes-used"],
          "object_count" => headers["x-account-object-count"],
          "container_count" => headers["x-account-container-count"]
        }
      end

      # Returns the following informations about the account:
      #   last-modified
      #   etag
      #   content-type
      def object_info(container, object)
        Openstack::Swift::WebApi.object_stat(@url, @token, container, object)
      end

      # This method uploads a file to a given container
      def upload(container, file_path, options={})
        options[:segments_size] ||= MAX_SIZE

        if File.size(file_path) > options[:segments_size]
          file_name = file_path.match(/.+\/(.+?)$/)[1]
          file_size  = File.size(file_path)
          file_mtime = File.mtime(file_path).to_f.round(2)

          full_file = File.open(file_path, "rb")
          segments_minus_one = File.size(file_path) / options[:segments_size]
          last_piece = File.size(file_path) - segments_minus_one * options[:segments_size]
          segments_minus_one.times do |i|
            segment_path = "#{file_name}/#{file_mtime}/#{file_size}/%08d" % i
            Openstack::Swift::WebApi.upload_object(@url, @token, "#{container}_segments", file_path, options[:segments_size] * i, options[:segments_size], segment_path)
          end

          segment_path = "#{file_path}/#{segments_minus_one}"
          Openstack::Swift::WebApi.upload_object(@url, @token, "#{container}_segments", file_path, options[:segments_size] * segments_minus_one, last_piece, segment_path)
          Openstack::Swift::WebApi.create_manifest(@url, @token, container, file_path)
        else
          Openstack::Swift::WebApi.upload_object(@url, @token, container, file_path)
        end
      ensure
        full_file.close rescue nil
      end

      # This method downloads a object from a given container
      def download(container, object)
        Openstack::Swift::WebApi.download_object(@url, @token, container, object)
      end
    end
  end
end
