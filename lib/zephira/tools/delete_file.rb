# frozen_string_literal: true

require "fileutils"

module Zephira
  class Tools
    class DeleteFile < BaseTool
      class << self
        def name
          "delete_file"
        end

        def description
          "Delete a file or directory and its contents."
        end

        def parameters
          {
            type: "object",
            properties: {
              intent: {type: "string", description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."},
              file_path: {type: "string", description: "Path to the file or directory to delete"}
            },
            required: ["file_path", "intent"]
          }
        end
      end

      def run
        path = validate(arg(:file_path), arg_path: "file_path", type: String)

        agent.status.verbose(" • Deleting file or directory: '#{path}'")

        expanded = ::File.expand_path(path)
        begin
          ::FileUtils.rm_rf(expanded)
        rescue Errno::EACCES
          return error_result(message: "Permission denied: #{path}")
        end

        agent.status.verbose(" • File or dir deleted: '#{path}'")
        agent.logger.info("File or dir deleted: '#{path}'")
        success_result("File or dir deleted: '#{path}'")
      end
    end
  end
end
