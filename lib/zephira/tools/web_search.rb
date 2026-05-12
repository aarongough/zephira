# frozen_string_literal: true

require "uri"
require "net/http"
require "json"

module Zephira
  class Tools
    class WebSearch < BaseTool
      class << self
        def name
          "web_search"
        end

        def description
          "Performs a web search using the Brave Search API."
        end

        def read_only?
          true
        end

        def parameters
          {
            type: "object",
            properties: {
              intent: {
                type: "string",
                description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."
              },
              queries: {
                type: "array",
                description: "An array of search query instructions",
                items: {
                  type: "object",
                  properties: {
                    query: {
                      type: "string",
                      description: "The string to search for"
                    },
                    num_results: {
                      type: "integer",
                      description: "Maximum number of results to return (1-50)",
                      minimum: 1,
                      maximum: 50
                    }
                  },
                  required: ["query", "num_results"],
                  additionalProperties: false
                }
              }
            },
            required: ["intent", "queries"]
          }
        end
      end

      def run
        queries = validate(arg(:queries), arg_path: "queries", type: Array, allow_empty: false)

        api_key = Config.read("ZEPHIRA_BRAVE_SEARCH_API_KEY").to_s
        if api_key.strip.empty?
          return error_result(message: "ZEPHIRA_BRAVE_SEARCH_API_KEY not set (env var or .zephira.yml)")
        end

        results = queries.map { |query| run_query(query, api_key) }
        success_result(results)
      end

      private

      def run_query(query_args, api_key)
        query = query_args["query"] || query_args[:query]
        num_results = query_args["num_results"] || query_args[:num_results]

        unless query.is_a?(String) && !query.strip.empty?
          return error_result(message: "`query` must be a non-empty string")
        end

        if num_results && (!num_results.is_a?(Integer) || !(1..50).cover?(num_results))
          return error_result(message: "`num_results` must be an integer between 1 and 50")
        end

        agent.update_status("    Web search: '#{query}'")

        uri = URI("https://api.search.brave.com/res/v1/web/search")
        params = {"q" => query}
        params["count"] = num_results if num_results
        uri.query = URI.encode_www_form(params)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        response = http.get(uri.request_uri, {"Accept" => "application/json", "X-Subscription-Token" => api_key})

        if response.code.to_i >= 300
          agent.status.warn(" • ERROR: '#{query}' search failed (#{response.code})")
          agent.logger.error("Search failed: '#{query}' (#{response.code})")
          return error_result(message: "Search failed with status #{response.code}")
        end

        begin
          data = JSON.parse(response.body)
          agent.status.verbose(" • Search complete: '#{query}'")
          agent.logger.info("Search complete: '#{query}'")
          success_result(data)
        rescue JSON::ParserError => error
          agent.status.warn(" • ERROR: Invalid JSON for '#{query}'")
          error_result(message: "Invalid JSON: #{error.message}")
        end
      end
    end
  end
end
