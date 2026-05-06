# frozen_string_literal: true

module Zephira
  class Completions
    class SlashCommands
      def self.complete(input:, agent:)
        return [] unless input.start_with?("/")

        prefix = input[1..] || ""
        agent.commands.constants
          .map(&:name)
          .grep(/\A#{Regexp.escape(prefix)}/)
          .map { |cmd| "/#{cmd}" }
      end
    end
  end
end
