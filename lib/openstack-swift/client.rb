module Openstack
  module Swift
    class Client
      def authenticate(proxy, user, password)
        @url, _, @token = Openstack::Swift::WebApi.auth(proxy, user, password)

        puts @url
        puts @token
        if @url.blank? or @token.blank?
          raise AuthenticationError
        else
          true
        end
      end

      def upload(container, file_path)
        Openstack::Swift::WebApi.upload_object(@url, @token, container, file_path)
      end

      def download(container, file_path)
        Openstack::Swift::WebApi.download_object(@url, @token, container, file_path)
      end
    end
  end
end
