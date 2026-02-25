# frozen_string_literal: true

require "json"
require "socket"

module Litestream
  class IPC
    class ConnectionError < StandardError
    end

    class << self
      def info(socket_path)
        request("/info", socket_path)
      end

      def list(socket_path)
        request("/list", socket_path)
      end

      private

      def request(path, socket_path)
        unless File.exist?(socket_path)
          raise ConnectionError, "Litestream IPC socket not found at #{socket_path}. Is the litestream daemon running?"
        end

        socket = UNIXSocket.new(socket_path)
        socket.write("GET #{path} HTTP/1.0\r\nHost: localhost\r\n\r\n")
        response = socket.read
        socket.close

        headers, body = response.split("\r\n\r\n", 2)
        status_code = headers.lines.first[/\d{3}/].to_i

        unless (200..299).cover?(status_code)
          raise ConnectionError, "Failed to connect to Litestream IPC socket at #{socket_path}: HTTP #{status_code}"
        end

        JSON.parse(body)
      rescue Errno::ENOENT, Errno::ECONNREFUSED, Errno::EPIPE, Errno::ECONNRESET => e
        raise ConnectionError, "Failed to connect to Litestream IPC socket at #{socket_path}: #{e.message}"
      rescue JSON::ParserError => e
        raise ConnectionError, "Failed to parse IPC response from #{socket_path}: #{e.message}"
      end
    end
  end
end
