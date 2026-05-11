# frozen_string_literal: true

require "json"

module Zephira
  module Models
    # Base class for all model definitions.
    #
    # To add a new model:
    #   1. Drop a new file in `lib/zephira/models/<name>.rb` — it is auto-loaded.
    #   2. Subclass `BaseModel` and implement `model_name` and `context_limit`.
    #   3. Optionally override `backend` to point at a specific backend class.
    #      Defaults to `Backends::OpenAiCompatible` (works for any provider with an
    #      OpenAI-compatible API). For provider-specific quirks (Mistral, Anthropic
    #      tool-call shape, etc.) define a dedicated backend class and return it
    #      from `backend`.
    #
    # `ENV["ZEPHIRA_BACKEND"]` overrides per-model `backend` for debugging.
    class BaseModel
      def self.model_name
        raise NotImplementedError, "You must implement the model_name method"
      end

      def self.context_limit
        raise NotImplementedError, "You must implement the context_limit method"
      end

      # Override in subclasses to bind a model to a specific backend class.
      def self.backend
        Zephira::Backends::OpenAiCompatible
      end

      def self.backend_class
        identifier = ENV["ZEPHIRA_BACKEND"]
        if identifier
          found = Zephira::Backends.find_by_name(identifier)
          return found if found
        end
        backend
      end

      def self.format_tools(tools)
        tools.to_h.map do |tool|
          {
            type: "function",
            function: {
              name: tool[:name],
              description: tool[:description],
              parameters: tool[:parameters]
            }
          }
        end
      end

      def self.inference(api_key:, agent:, messages: [], base_url: nil)
        client = backend_class.new(api_key: api_key, base_url: base_url)

        loop do
          agent.thinking(self)
          response = client.chat(
            model_name: model_name,
            messages: messages,
            agent: agent,
            tools: format_tools(agent.tools)
          )

          tool_calls = Array(response["tool_calls"]).select { |tool_call| tool_call["type"] == "function" }

          if tool_calls.empty?
            content = response["content"]
            return (content.nil? || content.empty?) ? nil : content
          end

          messages << {role: "assistant", content: response["content"], tool_calls: response["tool_calls"]}
          agent.history.append(role: "assistant", content: response["content"], tool_calls: response["tool_calls"])

          dispatch_tool_calls(tool_calls, agent: agent).each do |call, content|
            messages << {role: "tool", tool_call_id: call["id"], content: content}
            agent.history.append(role: "tool", tool_call_id: call["id"], content: content)
          end
        end
      end

      # Returns an array of [call, content] pairs in the original order. Read-only
      # tools are run concurrently via threads (network/disk I/O releases the GVL);
      # mutating tools run sequentially after, in original order.
      def self.dispatch_tool_calls(tool_calls, agent:)
        results = Array.new(tool_calls.size)

        read_only_calls = []
        mutating_calls = []
        tool_calls.each_with_index do |call, index|
          if agent.tools.read_only?(call["function"]["name"])
            read_only_calls << [index, call]
          else
            mutating_calls << [index, call]
          end
        end

        threads = read_only_calls.map do |index, call|
          Thread.new do
            args = parse_tool_arguments(call, agent: agent)
            result = agent.run_tool(name: call["function"]["name"], args: args)
            results[index] = [call, serialize_tool_result(result)]
          end
        end
        threads.each(&:join)

        mutating_calls.each do |index, call|
          args = parse_tool_arguments(call, agent: agent)
          result = agent.run_tool(name: call["function"]["name"], args: args)
          results[index] = [call, serialize_tool_result(result)]
        end

        results
      end

      def self.simple_inference(api_key:, messages:, agent: nil, base_url: nil)
        client = backend_class.new(api_key: api_key, base_url: base_url)
        agent.thinking(self) if agent.respond_to?(:thinking)
        client.chat(model_name: model_name, messages: messages, agent: agent)["content"]
      end

      def self.parse_tool_arguments(call, agent:)
        raw = call["function"]["arguments"] || "{}"
        JSON.parse(raw, symbolize_names: true)
      rescue JSON::ParserError => exception
        agent&.logger&.error("Failed to parse tool arguments for #{call["function"]["name"]}: #{exception.message}. Raw: #{raw.inspect}")
        {}
      end

      def self.serialize_tool_result(result)
        return result unless result.is_a?(Hash) && result.key?(:outcome)

        if result[:outcome] == "success"
          result[:data].is_a?(String) ? result[:data] : JSON.pretty_generate([result[:data]])
        else
          result[:error].to_s
        end
      end
    end
  end
end
