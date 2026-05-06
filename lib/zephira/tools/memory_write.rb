# frozen_string_literal: true

require "fileutils"
require "yaml"

module Zephira
  class Tools
    class MemoryWrite < BaseTool
      MEMORY_PATH = ".zephira/memory.yml"

      class << self
        def name
          "memory_write"
        end

        def description
          "Write a named value to persistent memory."
        end

        def parameters
          {
            type: "object",
            properties: {
              key: {type: "string", description: "Memory key"},
              value: {type: "string", description: "Value to store"},
              intent: {type: "string", description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."}
            },
            required: ["key", "value", "intent"]
          }
        end
      end

      def run
        key = validate(arg(:key), arg_path: "key", type: String)
        value = validate(arg(:value), arg_path: "value", type: String, allow_empty: true)

        memory = load_memory
        memory[key] = value
        save_memory(memory)

        agent.status.verbose(" • Memory written: '#{key}'")
        success_result("Memory written: '#{key}'")
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
