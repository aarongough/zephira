# frozen_string_literal: true

module Zephira
  class Commands
    class History
      class << self
        def name
          "history"
        end

        def description
          "Display the conversation history"
        end

        def run(agent:, args:)
          agent.history.messages.each do |message|
            content = message[:content].to_s
            content = "#{content.gsub("\n", "\\n").slice(0, 100)}..." if content.length > 100
            puts "[#{message[:timestamp]}] #{message[:role]}: #{content}"
          end
        end
      end
    end
  end
end
