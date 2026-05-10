# frozen_string_literal: true

module Zephira
  class Tools
    class MemoryWrite < BaseTool
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

        MemoryStore.write(key, value)

        agent.status.verbose(" • Memory written: '#{key}'")
        success_result("Memory written: '#{key}'")
      end
    end
  end
end
