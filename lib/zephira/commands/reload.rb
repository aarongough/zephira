# frozen_string_literal: true

module Zephira
  class Commands
    class Reload
      class << self
        def name
          "reload"
        end

        def description
          "Reload the agent by re-executing the process (picks up code changes)"
        end

        def run(agent:, args:)
          puts "Reloading…"
          argv = defined?(::Zephira::ORIGINAL_ARGV) ? ::Zephira::ORIGINAL_ARGV : []
          if ENV["BUNDLE_GEMFILE"] && File.exist?(ENV["BUNDLE_GEMFILE"])
            Kernel.exec("bundle", "exec", RbConfig.ruby, $PROGRAM_NAME, *argv)
          else
            Kernel.exec(RbConfig.ruby, $PROGRAM_NAME, *argv)
          end
        end
      end
    end
  end
end
