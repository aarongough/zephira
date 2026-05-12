# frozen_string_literal: true

require "spec_helper"

BRAVE_SEARCH_URL = "https://api.search.brave.com/res/v1/web/search"

RSpec.describe "web_search tool", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).and_call_original
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  def run_tool(args)
    agent.run_tool(name: "web_search", args: args)
  end

  def stub_brave(query:, num_results: 5, response_body: nil, status: 200)
    body = response_body || {web: {results: [{title: "Result", url: "https://example.com", description: "A result"}]}}.to_json
    stub_request(:get, BRAVE_SEARCH_URL)
      .with(query: hash_including("q" => query))
      .to_return(status: status, body: body, headers: {"Content-Type" => "application/json"})
  end

  around do |example|
    original = ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"]
    ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"] = "test-brave-key"
    example.run
    ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"] = original
  end

  describe "successful search" do
    before { stub_brave(query: "ruby programming") }

    it "returns success" do
      result = run_tool(queries: [{"query" => "ruby programming", "num_results" => 5}], intent: "search for ruby")
      expect(result).to be_success
    end

    it "returns an array of per-query results" do
      result = run_tool(queries: [{"query" => "ruby programming", "num_results" => 5}], intent: "search for ruby")
      expect(result[:data]).to be_an(Array)
      expect(result[:data].first[:outcome]).to eq("success")
    end
  end

  describe "multiple queries" do
    before do
      stub_brave(query: "ruby")
      stub_brave(query: "rails")
    end

    it "returns a result for each query" do
      result = run_tool(
        queries: [
          {"query" => "ruby", "num_results" => 3},
          {"query" => "rails", "num_results" => 3}
        ],
        intent: "multi-search"
      )
      expect(result[:data].size).to eq(2)
    end
  end

  describe "missing API key" do
    around do |example|
      original = ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"]
      ENV.delete("ZEPHIRA_BRAVE_SEARCH_API_KEY")
      example.run
      ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"] = original
    end

    it "returns an error" do
      result = run_tool(queries: [{"query" => "anything", "num_results" => 1}], intent: "search")
      expect(result).to be_error(/ZEPHIRA_BRAVE_SEARCH_API_KEY/)
    end
  end

  describe "API error response" do
    before { stub_brave(query: "bad query", status: 429) }

    it "returns a per-query error" do
      result = run_tool(queries: [{"query" => "bad query", "num_results" => 5}], intent: "search")
      expect(result).to be_success
      expect(result[:data].first[:outcome]).to eq("error")
      expect(result[:data].first[:error]).to match(/429/)
    end
  end

  describe "empty queries array" do
    it "returns an error" do
      result = run_tool(queries: [], intent: "empty search")
      expect(result).to be_error(/queries/)
    end
  end
end
