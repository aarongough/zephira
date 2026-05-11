# frozen_string_literal: true

module Zephira
  class Tools
    class ListDirectory < BaseTool
      class << self
        def name
          "list_directory"
        end

        def description
          "List the contents of a directory."
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
              directory_path: {
                type: "string",
                description: "Path to the directory to list"
              }
            },
            required: ["directory_path", "intent"]
          }
        end
      end

      def run
        dir_path = arg(:directory_path)
        if dir_path.nil? || dir_path.strip.empty?
          return error_result(message: "`directory_path` was empty or missing")
        end

        agent.status.verbose(" • Listing directory contents: '#{dir_path}'")
        expanded_path = ::File.expand_path(dir_path)
        entries = Dir.children(expanded_path)

        agent.status.verbose(" • Directory contents listed: #{entries.size} entries in '#{dir_path}'")
        agent.logger.info("Listing directory contents: '#{dir_path}'")
        success_result(entries)
      rescue Errno::ENOENT
        error_result(message: "Directory not found: '#{dir_path}'")
      rescue Errno::EACCES
        error_result(message: "Permission denied: #{dir_path}")
      end
    end
  end
end
