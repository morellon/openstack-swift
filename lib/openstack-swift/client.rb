# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
      # Authentication method
      # It stores the authentication url and token for future commands
      # Avoiding to request a new token for each request
      def authenticate(proxy, user, password)
        @url, _, @token = Openstack::Swift::WebApi.auth(proxy, user, password)

        if @url.blank? or @token.blank?
          raise AuthenticationError
        else
          true
        end
      end

      # Returns the following informations about the account:
      #   bytes_used: Number of bytes used by this account
      #   object_count: Number of objects that this account have allocated
      #   container_count: Number of container
      def account_info
        Openstack::Swift::WebApi.account(@url, @token)
      end

      # This method uploads a file to a given container
      def upload(container, file_path)
        Openstack::Swift::WebApi.upload_object(@url, @token, container, file_path)
      end

      # This method downloads a object from a given container
      def download(container, object)
        Openstack::Swift::WebApi.download_object(@url, @token, container, object)
      end
    end
  end
end
