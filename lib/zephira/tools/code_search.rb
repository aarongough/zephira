# frozen_string_literal: true

require "open3"
require "json"

module Zephira
  class Tools
    class CodeSearch < BaseTool
      class << self
        def name
          "code_search"
        end

        def description
          "Search codebase for symbols or patterns"
        end

        def parameters
          {
            type: "object",
            properties: {
              queries: {
                type: "array",
                items: {
                  type: "object",
                  properties: {
                    query: {type: "string", description: "String to search for"},
                    path: {type: "string", description: "Directory path to search"},
                    case_sensitive: {type: "boolean", description: "Enable case-sensitive search"},
                    max_results: {type: "integer", description: "Maximum number of results"}
                  },
                  required: ["query", "path"]
                }
              },
              intent: {
                type: "string",
                description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."
              }
            },
            required: ["queries", "intent"]
          }
        end
      end

      def run
        queries = arg(:queries)
        unless queries.is_a?(Array) && !queries.empty?
          return error_result(message: "argument `queries` must be a non-empty array")
        end

        results = queries.map { |query_args| run_query(query_args) }
        success_result(results)
      end

      private

      def run_query(query_args)
        query = query_args[:query] || query_args["query"]
        path = query_args[:path] || query_args["path"]
        case_sensitive = query_args[:case_sensitive] || query_args["case_sensitive"]
        max_results = query_args[:max_results] || query_args["max_results"]

        return error_result(message: "Path must be provided") if path.nil? || path.to_s.strip.empty?

        expanded_path = ::File.expand_path(path.to_s)
        return error_result(message: "Path not found: #{expanded_path}") unless ::Dir.exist?(expanded_path)

        return error_result(message: "Query must be a non-empty string") if query.nil? || !query.is_a?(String) || query.strip.empty?
        return error_result(message: "ripgrep (rg) not found") unless executable_available?("rg")

        agent.status.verbose(" • Text search for '#{query}' in '#{path}'")

        cmd = ["rg", "--json", "-C", "2", "-n"]
        cmd << "-i" unless case_sensitive
        cmd << query
        cmd << expanded_path

        stdout, stderr, status = Open3.capture3(*cmd)
        return error_result(message: "ripgrep failed: #{stderr.strip}") unless status.success?

        results = parse_rg_output(stdout, max_results)
        agent.status.verbose(" • Code search completed: found #{results.size} matches")
        success_result(results)
      end

      def parse_rg_output(stdout, max_results)
        results = []
        context_buffer = []
        current_file = nil

        stdout.each_line do |line|
          data = begin
            JSON.parse(line)
          rescue JSON::ParserError
            next
          end

          case data["type"]
          when "begin"
            current_file = data.dig("data", "path", "text")
            context_buffer = []
          when "match"
            context_buffer << {
              file: current_file,
              line: data["data"]["line_number"],
              content: data["data"]["lines"]["text"],
              match: true
            }
          when "context"
            context_buffer << {
              file: current_file,
              line: data["data"]["line_number"],
              content: data["data"]["lines"]["text"],
              match: false
            }
          when "end"
            results << context_buffer.sort_by { |entry| entry[:line] }
            break if max_results && results.size >= max_results
          end
        end

        results
      end

      def executable_available?(cmd)
        _, _, status = Open3.capture3("which", cmd)
        status.success?
      end
    end
  end
end
