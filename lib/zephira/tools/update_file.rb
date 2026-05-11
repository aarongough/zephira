# frozen_string_literal: true

require "fileutils"

module Zephira
  class Tools
    class UpdateFile < BaseTool
      class << self
        def name
          "update_file"
        end

        def description
          "Update or create a file by providing the full replacement content."
        end

        def parameters
          {
            type: "object",
            properties: {
              content: {type: "string", description: "Full replacement file text"},
              file_path: {type: "string", description: "Path to the file to be updated or created"},
              intent: {type: "string", description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."}
            },
            required: ["content", "file_path", "intent"]
          }
        end
      end

      def run
        content = validate(arg(:content), arg_path: "content", type: String, allow_empty: true)
        file_path = validate(arg(:file_path), arg_path: "file_path", type: String)

        agent.status.verbose(" • Updating file: '#{file_path}'")

        ::FileUtils.mkdir_p(::File.dirname(file_path))
        ::File.write(file_path, content)

        msg = "Updated file: '#{file_path}'"
        agent.status.verbose(" • #{msg}")
        agent.logger.info(msg)
        success_result(msg)
      end
    end
  end
end
