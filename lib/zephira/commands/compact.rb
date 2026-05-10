# frozen_string_literal: true

module Zephira
  class Commands
    class Compact
      class << self
        def name
          "compact"
        end

        def description
          "Summarize older history to free up context"
        end

        def run(agent:, args:)
          compacted = agent.compact_history(force: true)
          puts "Nothing to compact." unless compacted
        end
      end
    end
  end
end
