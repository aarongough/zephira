# frozen_string_literal: true

module Zephira
  class Commands
    class Help
      class << self
        def name
          "help"
        end

        def description
          "Display this help information"
        end

        def run(agent:, args:)
          lines = agent.commands.constants.map { |cmd| "  /#{cmd.name}: #{cmd.description}" }
          puts "Available commands:\n#{lines.join("\n")}\n\n"
        end
      end
    end
  end
end
