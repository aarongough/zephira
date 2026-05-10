# frozen_string_literal: true

module Zephira
  class Completions
    def self.load(paths:)
      paths.each do |path|
        Dir.glob(File.join(path, "**", "*.rb")).each { |file| require file }
      end
      new(paths)
    end

    def initialize(paths)
      @paths = paths
    end

    def constants
      @constants ||= ::Zephira::Completions.constants(false).map do |name|
        ::Zephira::Completions.const_get(name)
      end
    end

    def complete_all(input:, agent:)
      constants.flat_map { |completion| completion.complete(input: input, agent: agent) }.uniq
    end
  end
end
