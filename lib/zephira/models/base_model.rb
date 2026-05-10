# frozen_string_literal: true

require "json"

module Zephira
  module Models
    class BaseModel
      def self.model_name
        raise NotImplementedError, "You must implement the model_name method"
      end

      def self.context_limit
        raise NotImplementedError, "You must implement the context_limit method"
      end

      def self.backend_class
        identifier = ENV["ZEPHIRA_BACKEND"]
        if identifier
          found = Zephira::Backends.find_by_name(identifier)
          return found if found
        end
        Zephira::Backends::OpenAiCompatible
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
        client = backend_class.new(api_key: api_key, agent: agent, base_url: base_url)
        agent.thinking(self)

        response = client.chat(
          model_name: model_name,
          messages: messages,
          agent: agent,
          tools: format_tools(agent.tools)
        )

        tool_calls = Array(response["tool_calls"]).select { |tool_call| tool_call["type"] == "function" }

        if tool_calls.any?
          messages << {role: "assistant", content: response["content"], tool_calls: response["tool_calls"]}
          agent.history.append(role: "assistant", content: response["content"], tool_calls: response["tool_calls"])

          tool_calls.each do |call|
            args = begin
              JSON.parse(call["function"]["arguments"] || "{}", symbolize_names: true)
            rescue JSON::ParserError
              {}
            end

            result = agent.run_tool(name: call["function"]["name"], args: args)

            content = if result.is_a?(Hash) && result.key?(:outcome)
              if result[:outcome] == "success"
                result[:data].is_a?(String) ? result[:data] : JSON.pretty_generate([result[:data]])
              else
                result[:error].to_s
              end
            else
              result
            end

            messages << {role: "tool", tool_call_id: call["id"], content: content}
            agent.history.append(role: "tool", tool_call_id: call["id"], content: content)
          end

          inference(api_key: api_key, agent: agent, messages: messages, base_url: base_url)
        else
          content = response["content"]
          (content.nil? || content.empty?) ? nil : content
        end
      end

      def self.simple_inference(api_key:, messages:, agent: nil, base_url: nil)
        client = backend_class.new(api_key: api_key, agent: agent, base_url: base_url)
        agent.thinking(self) if agent.respond_to?(:thinking)
        client.chat(model_name: model_name, messages: messages, agent: agent)["content"]
      end
    end
  end
end
