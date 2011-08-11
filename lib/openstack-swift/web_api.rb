module Openstack
  module Swift
    module WebApi
      extend self

      def auth(proxy, user, password)
        res = HTTParty.get(proxy, :headers => {'X-Auth-User' => user, 'X-Auth-Key' => password})
        raise UnauthorizedError unless res.code == 200

        [res.headers["x-storage-url"],res.headers["x-storage-token"],res.headers["x-auth-token"]]
      end

      def account(url, token)
        query = {:format => "json"}
        res = HTTParty.head(url, :headers => {'X-Auth-Token'=> token}, :query => query)
        {
          "bytes_used" => res.headers["x-account-bytes-used"],
          "object_count" => res.headers["x-account-object-count"],
          "container_count" => res.headers["x-account-container-count"]
        }
      end

      # List containers
      # Note that swift only returns 1000 items, so to list more than this
      # you should use the marker option as the name of the last returned item (1000th item)
      # to return the next sequency (1001 - 2000)
      # query options: marker, prefix, limit
      def containers(url, token, query = {})
        query = query.merge(:format => "json")
        res = HTTParty.get(url, :headers => {'X-Auth-Token'=> token}, :query => query)
        res.to_a
      end

      # query options: marker, prefix, limit
      def objects(url, token, container, query = {} )
        query = query.merge(:format => "json")
        res = HTTParty.get("#{url}/#{container}", :headers => {'X-Auth-Token'=> token}, :query => query)
        res.to_a
      end
    end
  end
end
