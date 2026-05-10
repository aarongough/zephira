# frozen_string_literal: true

module Zephira
  class History
    STORAGE_DIR = ".zephira"
    STORAGE_FILE = "history.jsonl"
    COMPACTION_CHUNK_SIZE = 10

    attr_reader :messages, :session_start

    def initialize(messages = [])
      @storage_dir = File.join(Dir.pwd, STORAGE_DIR)
      @storage_file = File.join(@storage_dir, STORAGE_FILE)

      FileUtils.mkdir_p(@storage_dir)

      if messages.empty? && File.file?(@storage_file) && File.size(@storage_file) > 0
        @messages = load_from_disk
      else
        @messages = messages.dup
        write_all_to_disk
      end

      @session_start = @messages.size
    end

    def append(role:, content:, tool_calls: nil, tool_call_id: nil)
      entry = {
        role: role,
        content: content,
        tool_calls: tool_calls,
        tool_call_id: tool_call_id,
        timestamp: Time.now.iso8601
      }.compact
      @messages << entry
      persist_entry(entry)
    end

    def size
      @messages.sum { |message| approx_tokens_by_regex(message[:content].to_s) }
    end

    def compact(response_model:, api_key:, token_limit: Float::INFINITY)
      return unless size > token_limit

      chunks = []
      while size > token_limit
        chunks << @messages.shift(COMPACTION_CHUNK_SIZE)
      end

      chunks.each do |chunk|
        conversation = chunk.map { |message| "#{message[:role]}: #{message[:content]}" }.join("\n")
        summary = response_model.simple_inference(
          api_key: api_key,
          messages: [{role: "user", content: "Summarize the following conversation:\n#{conversation}"}]
        )

        @messages.unshift(
          role: "system",
          content: "[Summary of #{chunk.size} messages]\n#{summary}",
          timestamp: Time.now.iso8601
        )
      end

      write_all_to_disk
    end

    def clear
      @messages.clear
      write_all_to_disk
    end

    def clear_session
      return unless @session_start
      @messages = @messages[0...@session_start]
      write_all_to_disk
    end

    def compact_tool_messages!
      @messages = @messages
        .reject { |message| message[:role] == "tool" }
        .map do |message|
          next message unless message[:tool_calls]&.any?

          summary_lines = message[:tool_calls].map do |tool_call|
            name = tool_call.dig(:function, :name) || tool_call.dig("function", "name")
            arguments = tool_call.dig(:function, :arguments) || tool_call.dig("function", "arguments")
            arguments = JSON.parse(arguments, symbolize_names: true)
            "- `#{name}` with intent `#{arguments[:intent]}`"
          end
          summary_lines.unshift("Agent used tool(s):\n")
          {role: "assistant", content: summary_lines.join("\n"), timestamp: message[:timestamp]}
        end

      write_all_to_disk
    end

    private

    def approx_tokens_by_regex(text)
      text.scan(/\w+|[^\s\w]/).size
    end

    def load_from_disk
      File.readlines(@storage_file).map { |line| JSON.parse(line, symbolize_names: true) }
    end

    def persist_entry(entry)
      File.open(@storage_file, "a") { |file| file.puts JSON.generate(entry) }
    end

    def write_all_to_disk
      File.open(@storage_file, "w") { |file| @messages.each { |entry| file.puts JSON.generate(entry) } }
    end
  end
end
