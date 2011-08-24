# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
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
        @url, _, @token = Api.auth(@proxy, @user, @password)

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
        headers = Api.account(@url, @token)
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
        headers = Api.object_stat(@url, @token, container, object)
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

        Api.create_container(@url, @token, container) rescue nil

        file_name, file_mtime, file_size  = file_info(file_path)

        if file_size > options[:segments_size]
          Api.create_container(@url, @token, "#{container}_segments") rescue nil

          segments_minus_one = file_size / options[:segments_size]
          last_piece = file_size - segments_minus_one * options[:segments_size]
          segments_minus_one.times do |segment|
            upload_path_for(file_path, segment)
            Api.upload_object(
              @url, @token, "#{container}_segments", file_path,
              :size => options[:segments_size],
              :position => options[:segments_size] * segment,
              :object_name => upload_path_for(file_path, segment)
            )
          end

          Api.upload_object(
            @url, @token, "#{container}_segments", file_path,
            :size => last_piece,
            :position => options[:segments_size] * segments_minus_one,
            :object_name => upload_path_for(file_path, segments_minus_one)
          )

          Api.create_manifest(@url, @token, container, file_path)
        else
          Api.upload_object(@url, @token, container, file_path)
        end
      end

      # This method downloads a object from a given container
      def download(container, object)
        Api.download_object(@url, @token, container, object)
      end

      # Delete a given object from a given container
      def delete(container, object)
        object_info = Api.object_stat(@url, @token, container, object)

        if object_info["manifest"]
          Api.delete_objects_from_manifest(@url, @token, object_info)
        else
          Api.delete(@url, @token, container, object)
        end
      end

     private

      # Returns the standard swift path for a given file path and segment
      def upload_path_for(file_path, segment)
        "%s/%s/s/%08d" % (file_info(file_path) << segment)
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
