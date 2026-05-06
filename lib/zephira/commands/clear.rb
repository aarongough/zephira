# frozen_string_literal: true

module Zephira
  class Commands
    class Clear
      USAGE = "Usage: /clear [session|all]"

      class << self
        def name
          "clear"
        end

        def description
          "Clear history: 'session' clears current session, 'all' clears everything"
        end

        def run(agent:, args:)
          case args&.first
          when "session"
            agent.history.clear_session
            puts "Session history cleared."
          when "all"
            agent.history.clear
            puts "History cleared."
          else
            puts USAGE
          end
        end
      end
    end
  end
end
