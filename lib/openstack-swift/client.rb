# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
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

      # Returns the following informations about the account:
      #   bytes_used: Number of bytes used by this account
      #   object_count: Number of objects that this account have allocated
      #   container_count: Number of containers
      def account_info
        headers = Api.account(@url, @token)
        {
          "bytes_used" => headers["x-account-bytes-used"],
          "object_count" => headers["x-account-object-count"],
          "container_count" => headers["x-account-container-count"]
        }
      end

      # Returns the following informations about the object:
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
        Api.upload_object(@url, @token, container, file_path, options)
      end

      # This method downloads a object from a given container
      def download(container, object, options={})
        Api.download_object(@url, @token, container, object, options[:file_path])
      end

      # Delete a given object from a given container
      def delete(container, object)
        if object_info(container, object)["manifest"]
          Api.delete_objects_from_manifest(@url, @token, container, object)
        else
          Api.delete_object(@url, @token, container, object)
        end
      end
    end
  end
end
