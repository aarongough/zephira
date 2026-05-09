# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::WebSearch do
  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status) }

  BRAVE_URL = "https://api.search.brave.com/res/v1/web/search"

  around do |example|
    original = ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"]
    ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"] = "test-key"
    example.run
    ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"] = original
  end

  def run(args)
    described_class.run(args: args.merge("intent" => described_class.name), agent: agent)
  end

  def stub_brave(query:, status: 200, body: nil)
    body ||= {web: {results: [{title: "Result", url: "https://example.com"}]}}.to_json
    stub_request(:get, BRAVE_URL)
      .with(query: hash_including("q" => query))
      .to_return(status: status, body: body, headers: {"Content-Type" => "application/json"})
  end

  describe ".parameters" do
    it "requires intent and queries" do
      expect(described_class.parameters[:required]).to contain_exactly("intent", "queries")
    end

    it "defines query item schema with query and num_results" do
      items = described_class.parameters[:properties][:queries][:items]
      expect(items[:required]).to contain_exactly("query", "num_results")
    end
  end

  describe ".run" do
    context "argument validation" do
      it "errors when queries is missing" do
        result = run("intent" => described_class.name)
        expect(result).to be_error(/queries/)
      end

      it "errors when queries is empty" do
        result = run("queries" => [])
        expect(result).to be_error(/queries/)
      end
    end

    context "missing API key" do
      around do |example|
        original = ENV.delete("ZEPHIRA_BRAVE_SEARCH_API_KEY")
        example.run
        ENV["ZEPHIRA_BRAVE_SEARCH_API_KEY"] = original
      end

      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BRAVE_SEARCH_API_KEY").and_return(nil)
      end

      it "returns an error" do
        result = run("queries" => [{"query" => "ruby", "num_results" => 5}])
        expect(result).to be_error(/ZEPHIRA_BRAVE_SEARCH_API_KEY/)
      end
    end

    context "successful query" do
      before { stub_brave(query: "ruby") }

      it "returns success" do
        result = run("queries" => [{"query" => "ruby", "num_results" => 5}])
        expect(result).to be_success
      end

      it "returns an array with one per-query result" do
        result = run("queries" => [{"query" => "ruby", "num_results" => 5}])
        expect(result[:data].size).to eq(1)
        expect(result[:data].first[:outcome]).to eq("success")
      end

      it "emits verbose status and logs" do
        run("queries" => [{"query" => "ruby", "num_results" => 5}])
        expect(status).to have_received(:verbose).with(" • Searching: 'ruby'")
        expect(status).to have_received(:verbose).with(" • Search complete: 'ruby'")
        expect(logger).to have_received(:info).with("Search complete: 'ruby'")
      end
    end

    context "multiple queries" do
      before do
        stub_brave(query: "ruby")
        stub_brave(query: "rails")
      end

      it "returns one result per query" do
        result = run("queries" => [
          {"query" => "ruby", "num_results" => 3},
          {"query" => "rails", "num_results" => 3}
        ])
        expect(result[:data].size).to eq(2)
        expect(result[:data].map { |r| r[:outcome] }).to all(eq("success"))
      end
    end

    context "non-2xx API response" do
      before { stub_brave(query: "bad", status: 429) }

      it "returns top-level success with per-query error" do
        result = run("queries" => [{"query" => "bad", "num_results" => 5}])
        expect(result).to be_success
        expect(result[:data].first[:outcome]).to eq("error")
        expect(result[:data].first[:error]).to match(/429/)
      end

      it "warns via agent status" do
        run("queries" => [{"query" => "bad", "num_results" => 5}])
        expect(status).to have_received(:warn).with(/ ERROR.*bad.*429/)
      end
    end

    context "invalid JSON response" do
      before { stub_brave(query: "broken", body: "not json") }

      it "returns per-query error" do
        result = run("queries" => [{"query" => "broken", "num_results" => 5}])
        expect(result[:data].first[:outcome]).to eq("error")
        expect(result[:data].first[:error]).to match(/Invalid JSON/)
      end
    end

    context "invalid query arg" do
      before { allow(Dir).to receive(:exist?).and_return(true) }

      it "returns per-query error for empty query string" do
        result = run("queries" => [{"query" => "", "num_results" => 5}])
        expect(result[:data].first[:outcome]).to eq("error")
        expect(result[:data].first[:error]).to match(/query.*non-empty string/i)
      end

      it "returns per-query error for out-of-range num_results" do
        result = run("queries" => [{"query" => "ruby", "num_results" => 100}])
        expect(result[:data].first[:outcome]).to eq("error")
        expect(result[:data].first[:error]).to match(/num_results/)
      end
    end
  end
end
