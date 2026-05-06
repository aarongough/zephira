# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::UpdateFile do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status) }

  describe ".parameters" do
    it "defines content, file_path, and intent" do
      expect(described_class.parameters[:properties].keys).to contain_exactly(:content, :file_path, :intent)
    end
  end

  describe ".run" do
    let(:file_path) { "test.txt" }
    let(:content) { "new content" }
    let(:args) { {"content" => content, "file_path" => file_path, "intent" => described_class.name} }

    context "with valid inputs" do
      it "writes the file and returns success" do
        result = described_class.run(args: args, agent: agent)
        expect(File.read(file_path)).to eq(content)
        expect(result[:outcome]).to eq("success")
        expect(result[:data]).to eq("Updated file: '#{file_path}'")
      end

      it "logs and notifies the agent" do
        described_class.run(args: args, agent: agent)
        expect(status).to have_received(:verbose).with(" • Updating file: '#{file_path}'")
        expect(status).to have_received(:verbose).with(" • Updated file: '#{file_path}'")
        expect(logger).to have_received(:info).with("Updated file: '#{file_path}'")
      end

      it "creates parent directories if needed" do
        nested_args = args.merge("file_path" => "nested/dir/test.txt")
        described_class.run(args: nested_args, agent: agent)
        expect(File.read("nested/dir/test.txt")).to eq(content)
      end
    end

    context "with empty content" do
      let(:content) { "  " }

      it "returns error without writing the file" do
        result = described_class.run(args: args, agent: agent)
        expect(File.exist?(file_path)).to be false
        expect(result[:outcome]).to eq("error")
        expect(result[:error]).to match(/No replacement provided/)
      end
    end

    context "with missing file_path" do
      let(:args) { {"content" => content, "file_path" => "", "intent" => described_class.name} }

      it "returns error" do
        result = described_class.run(args: args, agent: agent)
        expect(result[:outcome]).to eq("error")
        expect(result[:error]).to match(/`file_path` must be of type String/)
      end
    end
  end
end
