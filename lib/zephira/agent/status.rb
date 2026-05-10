# frozen_string_literal: true

module Zephira
  class Agent
    class Status
      def initialize(agent)
        @agent = agent
      end

      def verbose(msg)
        return unless @agent.verbose
        @agent.update_status(msg)
      end

      def warn(msg)
        @agent.update_status(Formatter.color(:dark_red, msg))
      end
    end
  end
end
