# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
      MAX_SIZE = 4 * 1024 ** 3
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
        if File.size(file_path) > MAX_SIZE
          full_file = File.open(file_path, "rb")
          segments_minus_one = File.size(file_path) / MAX_SIZE
          last_piece = File.size(file_path) - segments_minus_one * MAX_SIZE
          segments_minus_one.times do |i|
            segment_path = "#{file_path}/#{i}"
            Openstack::Swift::WebApi.upload_object(@url, @token, "#{container}_segments", file_path, MAX_SIZE * i, MAX_SIZE, segment_path)
          end

          segment_path = "#{file_path}/#{segments_minus_one}"
          Openstack::Swift::WebApi.upload_object(@url, @token, "#{container}_segments", file_path, MAX_SIZE * segments_minus_one, last_piece, segment_path)

          # manifest
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
