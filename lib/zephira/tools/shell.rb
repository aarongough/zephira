# frozen_string_literal: true

require "open3"

module Zephira
  class Tools
    class Shell < BaseTool
      OUTPUT_TRUNCATION_WIDTH = 200
      TRUNCATION_OVERHEAD = 23

      class << self
        def name
          "shell"
        end

        def description
          "Run a shell command"
        end

        def parameters
          {
            type: "object",
            properties: {
              command: {type: "string", description: "Command to run"},
              intent: {type: "string", description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."}
            },
            required: ["command", "intent"]
          }
        end
      end

      def run
        cmd = validate(arg(:command), arg_path: "command", type: String, allow_empty: false)

        agent.status.verbose(" • Running shell command: '#{cmd}'")
        stdout_str, stderr_str, status_obj = Open3.capture3(cmd, chdir: Dir.pwd)

        unless stdout_str.to_s.empty?
          message = truncate_string_to_fit(
            prefix: " • Shell command stdout: ",
            text_array: stdout_str.lines,
            max_characters: OUTPUT_TRUNCATION_WIDTH
          )
          agent.status.verbose(message)
        end

        unless stderr_str.to_s.empty?
          message = truncate_string_to_fit(
            prefix: " • \e[91mShell command stderr:\e[0m ",
            text_array: stderr_str.lines,
            max_characters: OUTPUT_TRUNCATION_WIDTH
          )
          agent.status.verbose(message)
        end

        agent.status.verbose(" • Shell command completed with exit status: #{status_obj.exitstatus}")
        success_result(status: status_obj.exitstatus, stdout: stdout_str, stderr: stderr_str)
      rescue Errno::ENOENT
        error_result(message: "Command not found: #{arg(:command)}")
      end

      private

      def truncate_string_to_fit(prefix:, text_array:, max_characters:)
        postfix = " ... (~#{text_array.size - 1} more lines)"
        overhead = prefix.length + postfix.length + TRUNCATION_OVERHEAD
        available_length = max_characters - overhead

        sanitized = text_array.join
          .gsub(/\e\[[\d;?]*[@-~]/, "")
          .delete("\e")
          .gsub(/\r?\n/, " ")

        full = prefix + sanitized
        return full if full.length <= max_characters

        truncated = sanitized[0, available_length]
        prefix + truncated + postfix
      end
    end
  end
end
