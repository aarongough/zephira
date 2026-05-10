# frozen_string_literal: true

module Zephira
  class Tools
    class ReadFile < BaseTool
      DEFAULT_MAX_BYTES = 20 * 1024

      class << self
        def name
          "read_file"
        end

        def description
          "Read the contents of one or more files (up to a size threshold)."
        end

        def parameters
          {
            type: "object",
            properties: {
              intent: {
                type: "string",
                description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."
              },
              file_paths: {
                type: "array",
                items: {type: "string"},
                description: "Paths to the files to read"
              }
            },
            required: ["file_paths", "intent"]
          }
        end
      end

      def run
        paths = arg(:file_paths)
        begin
          validate(paths, arg_path: "file_paths", type: Array, allow_empty: false)
        rescue ToolUseError => error
          return error_result(message: error.message)
        end

        results = paths.map do |file_path|
          if file_path.nil? || file_path.strip.empty?
            agent.status.warn("`file_path` was empty or missing for entry")
            {"path" => file_path, "content" => "", "error" => "`file_path` was empty or missing"}
          else
            expanded_path = ::File.expand_path(file_path)
            begin
              size = ::File.size(expanded_path)
              agent.status.verbose(" • Reading file: '#{file_path}' (max #{DEFAULT_MAX_BYTES} bytes)")

              data = if size > DEFAULT_MAX_BYTES
                agent.status.verbose(" • File size #{size} bytes exceeds limit of #{DEFAULT_MAX_BYTES} bytes, truncating content")
                ::File.open(expanded_path, "rb") { |file| file.read(DEFAULT_MAX_BYTES) }
              else
                ::File.binread(expanded_path)
              end

              content = normalize_content(data)
              agent.status.verbose(" • Read file: '#{file_path}'")
              agent.logger.info("Read file: '#{file_path}'")
              {"path" => file_path, "content" => content}
            rescue Errno::ENOENT
              agent.status.warn(" • File not found: '#{file_path}'")
              agent.logger.error("File not found: '#{file_path}'")
              {"path" => file_path, "content" => "", "error" => "No such file or directory: #{file_path}"}
            rescue Errno::EACCES
              agent.status.warn(" • Permission denied: '#{file_path}'")
              agent.logger.error("Permission denied: '#{file_path}'")
              {"path" => file_path, "content" => "", "error" => "Permission denied: #{file_path}"}
            rescue Errno::EISDIR
              agent.status.warn(" • Is a directory: '#{file_path}'")
              agent.logger.error("Is a directory: '#{file_path}'")
              {"path" => file_path, "content" => "", "error" => "Is a directory: #{file_path}"}
            end
          end
        end

        success_result(results)
      end

      private

      def normalize_content(data)
        data.force_encoding(Encoding::UTF_8).scrub("?")
      end
    end
  end
end
