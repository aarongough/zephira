# frozen_string_literal: true

require "fileutils"
require "yaml"

module Zephira
  class Tools
    class MemoryDelete < BaseTool
      MEMORY_PATH = ".zephira/memory.yml"

      class << self
        def name
          "memory_delete"
        end

        def description
          "Delete a named key from persistent memory."
        end

        def parameters
          {
            type: "object",
            properties: {
              key: {type: "string", description: "Memory key to delete"},
              intent: {type: "string", description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."}
            },
            required: ["key", "intent"]
          }
        end
      end

      def run
        key = validate(arg(:key), arg_path: "key", type: String)
        memory = load_memory

        unless memory.key?(key)
          return error_result(message: "Key not found: #{key}")
        end

        memory.delete(key)
        save_memory(memory)

        agent.status.verbose(" • Memory deleted: '#{key}'")
        success_result("Memory deleted: '#{key}'")
      end

      private

      def load_memory
        return {} unless ::File.exist?(MEMORY_PATH)
        YAML.load_file(MEMORY_PATH) || {}
      end

      def save_memory(memory)
        ::FileUtils.mkdir_p(::File.dirname(MEMORY_PATH))
        ::File.write(MEMORY_PATH, memory.to_yaml)
      end
    end
  end
end
