# frozen_string_literal: true

module Zephira
  class Tools
    class ToolNotFoundError < StandardError; end
    class ToolExecutionError < StandardError; end
    class ToolResultError < StandardError; end

    def self.load(paths:)
      paths.each do |path|
        Dir.glob(File.join(path, "**", "*.rb")).each do |file|
          require File.expand_path(file)
        end
      end
      new(paths)
    end

    def initialize(paths)
      @paths = paths
    end

    def constants
      @constants ||= ::Zephira::Tools.constants(false).map do |const_sym|
        ::Zephira::Tools.const_get(const_sym)
      end - [
        ::Zephira::Tools::BaseTool,
        ::Zephira::Tools::ToolNotFoundError,
        ::Zephira::Tools::ToolExecutionError,
        ::Zephira::Tools::ToolResultError
      ]
    end

    def to_h
      constants.map do |tool|
        {
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters
        }
      end
    end

    def run(name:, args:, agent:)
      tool = constants.find { |candidate| candidate.name == name }
      raise ToolNotFoundError, "Tool not found: #{name}" if tool.nil?

      result = begin
        tool.run(args: args, agent: agent)
      rescue => exception
        raise ToolExecutionError, "Encountered an error when executing tool #{name}: #{exception.message}"
      end

      validate_result(result)
      result
    end

    private

    def validate_result(result)
      unless result.is_a?(Hash) && result.key?(:outcome) && result.key?(:error) && result.key?(:data)
        raise ToolResultError, "Tool result must be a hash with keys :outcome, :error, and :data. Got: #{result.inspect}"
      end

      unless %w[success error].include?(result[:outcome])
        raise ToolResultError, "Tool result :outcome must be 'success' or 'error'. Got: #{result[:outcome].inspect}"
      end
    end
  end
end
