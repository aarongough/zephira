# frozen_string_literal: true

module Zephira
  class Commands
    class Bye
      class << self
        def name
          "bye"
        end

        def description
          "End the session and close the agent"
        end

        def run(agent:, args:)
          puts "Bye!"
          exit
        end
      end
    end
  end
end
