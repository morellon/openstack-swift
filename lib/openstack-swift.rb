# -*- coding: UTF-8 -*-
require "httparty"
require "net/http"
require "net/https"
require "fileutils"
require "openstack-swift/api"
require "openstack-swift/errors"
require "openstack-swift/client"
require "openstack-swift/swift_config"

module Openstack
  module Swift
  end
end

module Net
  class HTTPGenericRequest
    private
    def send_request_with_body_stream(sock, ver, path, f)
      unless content_length() or chunked?
        raise ArgumentError,
          "Content-Length not given and Transfer-Encoding is not `chunked'"
      end
      supply_default_content_type
      write_header sock, ver, path
      if chunked?
        while s = f.read(1024)
          sock.write(sprintf("%x\r\n", s.length) << s << "\r\n")
        end
        sock.write "0\r\n\r\n"
      else
        bytes_written = 0
        buffer=1024
        while (s = f.read(buffer)) && bytes_written < content_length()
          sock.write s
          bytes_written += buffer
        end
      end
    end
  end
end
