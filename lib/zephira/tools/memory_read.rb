# frozen_string_literal: true

module Zephira
  class Tools
    class MemoryRead < BaseTool
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

        unless MemoryStore.key?(key)
          return error_result(message: "Key not found: #{key}")
        end

        agent.status.verbose(" • Memory read: '#{key}'")
        success_result(MemoryStore.read(key))
      end
    end
  end
end
