# frozen_string_literal: true

require "net/http"
require "uri"

module Zephira
  class Tools
    class HttpRequest < BaseTool
      class << self
        def name
          "http_request"
        end

        def description
          "Perform HTTP requests: GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS"
        end

        def parameters
          {
            type: "object",
            properties: {
              intent: {
                type: "string",
                description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."
              },
              method: {
                type: "string",
                enum: ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
              },
              url: {
                type: "string",
                description: "Request URL"
              },
              headers: {
                type: "object",
                description: "Request headers as key-value pairs"
              },
              query: {
                type: "object",
                description: "Query parameters as key-value pairs"
              },
              body: {
                type: ["string", "object"],
                description: "Request body as string or JSON object"
              },
              timeout: {
                type: "number",
                description: "Timeout in seconds for open/read"
              }
            },
            required: ["intent", "method", "url"]
          }
        end
      end

      def run
        http_method = arg(:method)
        url = arg(:url)
        headers = arg(:headers) || {}
        query = arg(:query) || {}
        body = arg(:body)
        timeout = arg(:timeout)

        uri = URI.parse(url)
        uri.query = URI.encode_www_form(query) if query.is_a?(Hash) && !query.empty?

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = timeout if timeout
        http.read_timeout = timeout if timeout

        request_class =
          case http_method.to_s.upcase
          when "GET" then Net::HTTP::Get
          when "POST" then Net::HTTP::Post
          when "PUT" then Net::HTTP::Put
          when "PATCH" then Net::HTTP::Patch
          when "DELETE" then Net::HTTP::Delete
          when "HEAD" then Net::HTTP::Head
          when "OPTIONS" then Net::HTTP::Options
          else
            return error_result(message: "Unsupported HTTP method: #{http_method}")
          end

        req = request_class.new(uri)
        headers.each { |k, v| req[k] = v.to_s }

        if body
          if body.is_a?(Hash)
            req.body = body.to_json
            req["Content-Type"] ||= "application/json"
          else
            req.body = body.to_s
          end
        end

        agent.status.verbose(" • #{http_method} #{url}")
        response = http.request(req)
        agent.status.verbose(" • Response: #{response.code}")
        agent.logger.info("#{http_method} #{url} -> #{response.code}")

        success_result(status: response.code.to_i, headers: response.each_header.to_h, body: response.body)
      rescue => e
        error_result(message: e.message)
      end
    end
  end
end
