module Openstack
  module Swift
    module WebApi
      extend self

      def auth(proxy, user, password)
        res = HTTParty.get(proxy, :headers => {'X-Auth-User' => user, 'X-Auth-Key' => password})
        raise UnauthorizedError unless res.code == 200

        [res.headers["x-storage-url"],res.headers["x-storage-token"],res.headers["x-auth-token"]]
      end
    end
  end
end
