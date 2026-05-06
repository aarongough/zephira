# frozen_string_literal: true

require "yaml"

module Zephira
  class Tools
    class MemoryRead < BaseTool
      MEMORY_PATH = ".zephira/memory.yml"

      class << self
        def name
          "memory_read"
        end

        def description
          "Read a named value from persistent memory."
        end

        def parameters
          {
            type: "object",
            properties: {
              key: {type: "string", description: "Memory key to read"},
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

        agent.status.verbose(" • Memory read: '#{key}'")
        success_result(memory[key])
      end

      private

      def load_memory
        return {} unless ::File.exist?(MEMORY_PATH)
        YAML.load_file(MEMORY_PATH) || {}
      end
    end
  end
end
