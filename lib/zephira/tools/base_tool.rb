# frozen_string_literal: true

module Zephira
  class Tools
    class BaseTool
      class ToolUseError < StandardError; end

      attr_reader :args, :agent

      def initialize(args:, agent:)
        @args = args
        @agent = agent
      end

      def arg(name)
        @args[name] || @args[name.to_s]
      end

      def validate(actual, arg_path:, type:, allow_nil: false, allow_empty: false)
        if !allow_nil && actual.nil?
          raise ToolUseError, "argument `#{arg_path}` must be supplied"
        end

        unless actual.is_a?(type)
          raise ToolUseError, "argument `#{arg_path}` must be of type #{type} and non-empty"
        end

        if type == String && !allow_empty && actual.respond_to?(:strip) && actual.strip.empty?
          raise ToolUseError, "argument `#{arg_path}` must be of type #{type} and non-empty"
        end

        if !allow_empty && actual.respond_to?(:empty?) && actual.empty?
          raise ToolUseError, "argument `#{arg_path}` must be of type #{type} and non-empty"
        end

        actual
      end

      def run
        raise NotImplementedError, "This method should be overridden in a subclass"
      end

      def error_result(message:)
        {outcome: "error", error: message, data: nil}
      end

      def success_result(data)
        {outcome: "success", error: nil, data: data}
      end

      class << self
        def run(args:, agent:)
          result = begin
            tool_instance = new(args: args, agent: agent)
            intent_value = tool_instance.arg(:intent)
            tool_instance.validate(intent_value, arg_path: "args[:intent]", type: String)
            agent.update_status(Formatter.color(:green, "→ ") + intent_value)
            tool_instance.run
          rescue => exception
            log_message = "Tool call `#{name}` with args `#{args.inspect}` returned error: #{exception.message}"
            agent.logger.warn(log_message)
            agent.status.warn("ERROR: Tool call `#{name}` returned error: #{exception.message}")
            return {outcome: "error", error: exception.message, data: nil}
          end

          if result[:outcome] == "success"
            agent.logger.info("Tool call `#{name}` with args `#{args.inspect}` completed successfully: #{result[:data]}")
            agent.status.verbose("Tool call `#{name}` completed successfully")
          elsif result[:outcome] == "error"
            agent.logger.warn("Tool call `#{name}` with args `#{args.inspect}` returned error: #{result[:error]}")
            agent.status.warn("ERROR: Tool call `#{name}` returned error: #{result[:error]}")
          end

          result
        end

        def as_json
          {
            type: "function",
            function: {
              name: name,
              description: description,
              parameters: parameters
            }
          }
        end

        def name
          raise NotImplementedError, "This method should be overridden in a subclass"
        end

        def description
          raise NotImplementedError, "This method should be overridden in a subclass"
        end

        def parameters
          raise NotImplementedError, "This method should be overridden in a subclass"
        end

      end
    end
  end
end
