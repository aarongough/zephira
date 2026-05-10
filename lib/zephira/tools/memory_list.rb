# frozen_string_literal: true

module Zephira
  class Tools
    class MemoryList < BaseTool
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
        keys = MemoryStore.keys
        agent.status.verbose(" • Memory list: #{keys.size} keys")
        success_result(keys)
      end
    end
  end
end
