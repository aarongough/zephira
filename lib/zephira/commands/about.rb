# frozen_string_literal: true

module Zephira
  class Commands
    class About
      class << self
        def name
          "about"
        end

        def description
          "Display information about the agent"
        end

        def run(agent:, args:)
          puts [
            "Zephira: A toy coding agent",
            "  Version: #{::Zephira::VERSION}",
            "  https://github.com/aarongough/zephira",
            "",
            "Released under the MIT license."
          ].join("\n")
        end
      end
    end
  end
end
