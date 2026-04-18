# frozen_string_literal: true

require "optparse"

module Zephira
  class CLI
    def initialize(argv)
      option_parser.parse!(argv)
      Zephira::Agent.new.run_loop
    rescue OptionParser::InvalidOption
      puts option_parser
      exit(1)
    end

    private

    def option_parser
      OptionParser.new do |opts|
        opts.banner = "Usage: zephira [options]"

        opts.on("-v", "--version", "Print the version") do
          puts Zephira::VERSION
          exit(0)
        end

        opts.on("-h", "--help", "Print this help") do
          puts opts
          exit(0)
        end
      end
    end
  end
end
