# frozen_string_literal: true

require "faraday"
require "fileutils"
require "json"
require "time"

module Zephira
  module Backends
    class OpenAiCompatible
      def self.name
        "openai_compatible"
      end

      REQUEST_TIMEOUT = 300

      def initialize(api_key:, agent:, base_url: nil)
        @api_key = api_key
        @agent = agent
        @base_url = base_url || "https://api.openai.com/v1"
      end

      def chat(model_name:, messages:, agent:, tools: nil, options: {})
        payload = {
          model: model_name,
          messages: messages,
          tools: tools
        }.merge(options).compact

        debug_log(payload) if ENV["DEBUG"] == "true"

        client = Faraday.new(
          url: @base_url,
          headers: {
            "Authorization" => "Bearer #{@api_key}",
            "Content-Type" => "application/json"
          },
          request: {timeout: REQUEST_TIMEOUT}
        ) do |faraday|
          faraday.request :json
          faraday.response :raise_error
          faraday.adapter Faraday.default_adapter
        end

        response = client.post("chat/completions", JSON.generate(payload))
        raw = JSON.parse(response.body)

        agent.logger.info "OpenAI API response: #{raw.inspect}"
        raw.dig("choices", 0, "message") || {}
      rescue => exception
        agent.logger.error "OpenAI API request failed: #{exception.class}: #{exception.message}"
        if exception.respond_to?(:response) && exception.response
          agent.logger.error "Response status: #{exception.response[:status]}"
          agent.logger.error "Response body: #{exception.response[:body]}"
        end
        raise
      end

      private

      def debug_log(parameters)
        log_dir = File.join(Dir.pwd, ".zephira", "logs")
        FileUtils.mkdir_p(log_dir)
        timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%S%L")
        filepath = File.join(log_dir, "#{timestamp}_openai_request.log")
        File.write(filepath, JSON.pretty_generate({
          timestamp: Time.now.utc.iso8601,
          base_url: @base_url,
          parameters: parameters
        }))
        @agent.logger.debug "OpenAI request logged to: #{filepath}"
      end
    end
  end
end
