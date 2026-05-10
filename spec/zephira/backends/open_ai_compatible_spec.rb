require "spec_helper"

RSpec.describe Zephira::Backends::OpenAiCompatible do
  let(:api_key) { "test-key" }
  let(:base_url) { "https://api.openai.com/v1" }
  let(:logger) { instance_double(Zephira::Logger, info: nil, error: nil, debug: nil) }
  let(:agent) { double("Zephira::Agent", logger: logger) }
  let(:backend) { described_class.new(api_key: api_key) }

  let(:success_response) do
    {
      choices: [{
        message: {
          role: "assistant",
          content: "Hello!"
        }
      }]
    }.to_json
  end

  describe ".name" do
    it "returns the backend identifier" do
      expect(described_class.name).to eq("openai_compatible")
    end
  end

  describe "#chat" do
    it "posts to the chat completions endpoint and returns the message" do
      stub_request(:post, "#{base_url}/chat/completions")
        .to_return(status: 200, body: success_response, headers: {"Content-Type" => "application/json"})

      result = backend.chat(model_name: "gpt-4o-mini", messages: [], agent: agent)

      expect(result).to eq({"role" => "assistant", "content" => "Hello!"})
    end

    it "sends the api key as a bearer token" do
      stub_request(:post, "#{base_url}/chat/completions")
        .with(headers: {"Authorization" => "Bearer #{api_key}"})
        .to_return(status: 200, body: success_response, headers: {"Content-Type" => "application/json"})

      expect { backend.chat(model_name: "gpt-4o-mini", messages: [], agent: agent) }.not_to raise_error
    end

    it "includes tools in the payload when provided" do
      tools = [{type: "function", function: {name: "shell", description: "Run a shell command"}}]

      stub_request(:post, "#{base_url}/chat/completions")
        .with { |req| JSON.parse(req.body)["tools"] == JSON.parse(tools.to_json) }
        .to_return(status: 200, body: success_response, headers: {"Content-Type" => "application/json"})

      result = backend.chat(model_name: "gpt-4o-mini", messages: [], agent: agent, tools: tools)
      expect(result).to include("content" => "Hello!")
    end

    it "returns an empty hash when choices are missing" do
      stub_request(:post, "#{base_url}/chat/completions")
        .to_return(status: 200, body: {}.to_json, headers: {"Content-Type" => "application/json"})

      result = backend.chat(model_name: "gpt-4o-mini", messages: [], agent: agent)
      expect(result).to eq({})
    end

    it "raises and logs on API error" do
      stub_request(:post, "#{base_url}/chat/completions")
        .to_return(status: 401, body: '{"error": "Unauthorized"}')

      expect(logger).to receive(:error).at_least(:once)
      expect {
        backend.chat(model_name: "gpt-4o-mini", messages: [], agent: agent)
      }.to raise_error(Faraday::Error)
    end

    it "uses a custom base_url when provided" do
      custom_url = "https://my-proxy.example.com/v1"
      custom_backend = described_class.new(api_key: api_key, base_url: custom_url)

      stub_request(:post, "#{custom_url}/chat/completions")
        .to_return(status: 200, body: success_response, headers: {"Content-Type" => "application/json"})

      result = custom_backend.chat(model_name: "gpt-4o-mini", messages: [], agent: agent)
      expect(result).to include("content" => "Hello!")
    end
  end
end
