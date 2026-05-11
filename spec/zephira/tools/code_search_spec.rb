# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe Zephira::Tools::CodeSearch do
  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status, update_status: nil) }

  describe ".parameters" do
    it "defines queries and intent at the top level" do
      params = described_class.parameters
      expect(params[:properties].keys).to contain_exactly(:queries, :intent)
      expect(params[:required]).to contain_exactly("queries", "intent")
    end

    it "defines query items schema" do
      items = described_class.parameters[:properties][:queries][:items]
      expect(items[:properties].keys).to contain_exactly(:query, :path, :case_sensitive, :max_results)
    end
  end

  describe ".run" do
    context "when queries is missing" do
      it "returns error" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `queries` must be a non-empty array")
      end
    end

    context "when queries is an empty array" do
      it "returns error" do
        result = described_class.run(args: {"queries" => [], "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `queries` must be a non-empty array")
      end
    end

    context "when path does not exist" do
      it "returns success with per-query error in data" do
        result = described_class.run(
          args: {"queries" => [{"query" => "foo", "path" => "/nonexistent/path"}], "intent" => described_class.name},
          agent: agent
        )
        expect(result).to be_success
        expect(result[:data].first[:outcome]).to eq("error")
        expect(result[:data].first[:error]).to match(/Path not found/)
      end
    end

    context "when query is empty" do
      before { allow(Dir).to receive(:exist?).and_return(true) }

      it "returns success with per-query error for empty query" do
        result = described_class.run(
          args: {"queries" => [{"query" => "", "path" => "/some/path"}], "intent" => described_class.name},
          agent: agent
        )
        expect(result).to be_success
        expect(result[:data].first[:error]).to match(/Query must be a non-empty string/)
      end
    end

    context "when rg is not available" do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Open3).to receive(:capture3).with("command", "-v", "rg").and_return(["", "", double(success?: false)])
      end

      it "returns per-query error for missing rg" do
        result = described_class.run(
          args: {"queries" => [{"query" => "foo", "path" => "/some/path"}], "intent" => described_class.name},
          agent: agent
        )
        expect(result[:data].first[:error]).to match(/ripgrep \(rg\) not found/)
      end
    end

    context "when rg finds matches" do
      let(:rg_json) do
        [
          {type: "begin", data: {path: {text: "/project/file.rb"}}}.to_json,
          {type: "match", data: {line_number: 5, lines: {text: "def foo\n"}}}.to_json,
          {type: "end", data: {}}.to_json,
          {type: "summary", data: {}}.to_json
        ].join("\n")
      end

      before do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Open3).to receive(:capture3).with("command", "-v", "rg").and_return(["rg", "", double(success?: true)])
        allow(Open3).to receive(:capture3).with("rg", "--json", "-C", "2", "-n", "-i", "foo", "/some/path")
          .and_return([rg_json, "", double(success?: true)])
      end

      it "returns success with match results" do
        result = described_class.run(
          args: {"queries" => [{"query" => "foo", "path" => "/some/path"}], "intent" => described_class.name},
          agent: agent
        )
        expect(result).to be_success
        query_result = result[:data].first
        expect(query_result[:outcome]).to eq("success")
        expect(query_result[:data].first.first).to include({file: "/project/file.rb", line: 5, match: true})
      end

      it "notifies the agent" do
        described_class.run(
          args: {"queries" => [{"query" => "foo", "path" => "/some/path"}], "intent" => described_class.name},
          agent: agent
        )
        expect(status).to have_received(:verbose).with(" • Text search for 'foo' in '/some/path'")
        expect(status).to have_received(:verbose).with(" • Code search completed: found 1 matches")
      end
    end

    context "when case_sensitive is true" do
      before do
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Open3).to receive(:capture3).with("command", "-v", "rg").and_return(["rg", "", double(success?: true)])
        allow(Open3).to receive(:capture3).with("rg", "--json", "-C", "2", "-n", "Foo", "/some/path")
          .and_return(["", "", double(success?: true)])
      end

      it "omits the -i flag" do
        described_class.run(
          args: {"queries" => [{"query" => "Foo", "path" => "/some/path", "case_sensitive" => true}], "intent" => described_class.name},
          agent: agent
        )
        expect(Open3).to have_received(:capture3).with("rg", "--json", "-C", "2", "-n", "Foo", "/some/path")
      end
    end
  end
end
