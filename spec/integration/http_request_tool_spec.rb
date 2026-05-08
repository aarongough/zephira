# frozen_string_literal: true

require "spec_helper"

RSpec.describe "http_request tool", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  def run_tool(args)
    agent.run_tool(name: "http_request", args: args)
  end

  describe "GET request" do
    before do
      stub_request(:get, "https://example.com/api")
        .to_return(status: 200, body: '{"hello":"world"}', headers: {"Content-Type" => "application/json"})
    end

    it "returns success" do
      result = run_tool(method: "GET", url: "https://example.com/api", intent: "fetch example")
      expect(result).to be_success
    end

    it "returns the response status, headers, and body" do
      result = run_tool(method: "GET", url: "https://example.com/api", intent: "fetch example")
      expect(result[:data][:status]).to eq(200)
      expect(result[:data][:body]).to eq('{"hello":"world"}')
      expect(result[:data][:headers]).to include("content-type" => "application/json")
    end
  end

  describe "POST request with JSON body" do
    before do
      stub_request(:post, "https://example.com/api")
        .with(body: '{"key":"value"}', headers: {"Content-Type" => "application/json"})
        .to_return(status: 201, body: '{"created":true}', headers: {})
    end

    it "sends the body and returns success" do
      result = run_tool(method: "POST", url: "https://example.com/api", body: {key: "value"}, intent: "post data")
      expect(result).to be_success
      expect(result[:data][:status]).to eq(201)
    end
  end

  describe "query parameters" do
    before do
      stub_request(:get, "https://example.com/search")
        .with(query: {"q" => "ruby"})
        .to_return(status: 200, body: "results", headers: {})
    end

    it "appends query params to the URL" do
      result = run_tool(method: "GET", url: "https://example.com/search", query: {q: "ruby"}, intent: "search")
      expect(result).to be_success
    end
  end

  describe "custom headers" do
    before do
      stub_request(:get, "https://example.com/secure")
        .with(headers: {"Authorization" => "Bearer token123"})
        .to_return(status: 200, body: "ok", headers: {})
    end

    it "sends the custom headers" do
      result = run_tool(method: "GET", url: "https://example.com/secure", headers: {"Authorization" => "Bearer token123"}, intent: "auth request")
      expect(result).to be_success
    end
  end

  describe "error handling" do
    it "returns an error on connection failure" do
      stub_request(:get, "https://unreachable.example.com/").to_raise(SocketError.new("getaddrinfo: nodename nor servname provided"))
      result = run_tool(method: "GET", url: "https://unreachable.example.com/", intent: "bad request")
      expect(result).to be_error(/getaddrinfo/)
    end
  end
end
