# frozen_string_literal: true

module Zephira
  class Commands
    def self.load(paths:)
      paths.each do |path|
        Dir.glob(File.join(path, "**", "*.rb")).each { |f| require f }
      end
      new(paths)
    end

    def initialize(paths)
      @paths = paths
    end

    def constants
      @constants ||= ::Zephira::Commands.constants(false).map do |name|
        ::Zephira::Commands.const_get(name)
      end
    end

    def run(name:, args:, agent:)
      command_class = constants.find { |cmd| cmd.name == name }
      if command_class.nil?
        puts "Unknown command '/#{name}'. Type /help for a list of commands."
      else
        command_class.run(agent: agent, args: args)
      end
    end

    def to_h
      constants.map { |cmd| {name: cmd.name, description: cmd.description} }
    end
  end
end
