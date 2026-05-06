# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::ReadFile do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status) }

  describe ".run" do
    context "argument validation" do
      it "errors if file_paths is missing" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `file_paths` must be supplied")
      end

      it "errors if file_paths is empty" do
        result = described_class.run(args: {"file_paths" => [], "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `file_paths` must be of type Array and non-empty")
      end
    end

    context "when reading multiple files" do
      before do
        File.write("a.txt", "hello")
        File.write("b.txt", "world")
      end

      it "returns an array of path/content results" do
        result = described_class.run(args: {"file_paths" => ["a.txt", "b.txt"], "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data]).to match_array([
          {"path" => "a.txt", "content" => "hello"},
          {"path" => "b.txt", "content" => "world"}
        ])
      end
    end

    context "when reading a single file" do
      before { File.write("solo.txt", "solo") }

      it "returns a single-element array" do
        result = described_class.run(args: {"file_paths" => ["solo.txt"], "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data]).to eq([{"path" => "solo.txt", "content" => "solo"}])
      end
    end

    context "when file does not exist" do
      it "includes error entry and warns" do
        result = described_class.run(args: {"file_paths" => ["missing.txt"], "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data].first["error"]).to eq("No such file or directory: missing.txt")
        expect(status).to have_received(:warn).with(" • File not found: 'missing.txt'")
      end
    end

    context "when path is a directory" do
      before { FileUtils.mkdir_p("mydir") }

      it "includes error entry for directory" do
        result = described_class.run(args: {"file_paths" => ["mydir"], "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data].first["error"]).to eq("Is a directory: mydir")
      end
    end

    context "when file exceeds size limit" do
      let(:big_content) { "x" * (Zephira::Tools::ReadFile::DEFAULT_MAX_BYTES + 1) }

      before { File.write("big.txt", big_content) }

      it "truncates content to the limit" do
        result = described_class.run(args: {"file_paths" => ["big.txt"], "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data].first["content"].length).to eq(Zephira::Tools::ReadFile::DEFAULT_MAX_BYTES)
      end
    end
  end
end
