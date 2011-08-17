# -*- coding: UTF-8 -*-
module Openstack
  module Swift
    class Client
      MAX_SIZE = 5 * 1000 ** 3
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
          segments = (File.size(file_path) / MAX_SIZE) + 1
          segments.times do |i|
            segment_path = "/tmp/swift/#{file_path}/#{i}"
            segment_file = File.open(segment_path, "wb") do |f|
              buffer = MAX_SIZE / 1000
              total_buffer = 0
              while  total_buffer < MAX_SIZE
                puts "total_buffer: #{total_buffer}"
                content = full_file.read(buffer)
                f.write content
                total_buffer += buffer
              end
            end
            # Openstack::Swift::WebApi.upload_object(@url, @token, "#{container}_segments", segment_path)
          end
          # manifest
        else
          Openstack::Swift::WebApi.upload_object(@url, @token, container, file_path)
        end
      end

      # This method downloads a object from a given container
      def download(container, object)
        Openstack::Swift::WebApi.download_object(@url, @token, container, object)
      end
    end
  end
end
