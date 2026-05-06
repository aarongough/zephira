# frozen_string_literal: true

require "yaml"

module Zephira
  class Tools
    class MemoryList < BaseTool
      MEMORY_PATH = ".zephira/memory.yml"

      class << self
        def name
          "memory_list"
        end

        def description
          "List all stored memory keys."
        end

        def parameters
          {
            type: "object",
            properties: {
              intent: {type: "string", description: "Brief summary of intent of the operation, meant to be used for context compaction and presentation to the user. Use active voice (e.g., 'Reading X to do Y')."}
            },
            required: ["intent"]
          }
        end
      end

      def run
        memory = load_memory
        agent.status.verbose(" • Memory list: #{memory.size} keys")
        success_result(memory.keys)
      end

      private

      def load_memory
        return {} unless ::File.exist?(MEMORY_PATH)
        YAML.load_file(MEMORY_PATH) || {}
      end
    end
  end
end
