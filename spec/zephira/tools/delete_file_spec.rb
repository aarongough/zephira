# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::DeleteFile do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", status: status, logger: logger, update_status: nil) }

  describe ".parameters" do
    it "defines file_path and intent" do
      expect(described_class.parameters[:properties].keys).to contain_exactly(:file_path, :intent)
      expect(described_class.parameters[:required]).to eq(["file_path", "intent"])
    end
  end

  describe ".run" do
    it "errors when file_path is missing" do
      result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
      expect(result[:outcome]).to eq("error")
      expect(result[:error]).to match(/argument `file_path` must be supplied/)
    end

    context "when deleting an existing file" do
      before { File.write("foo.txt", "data") }

      it "deletes the file and returns success" do
        result = described_class.run(args: {"file_path" => "foo.txt", "intent" => described_class.name}, agent: agent)
        expect(File.exist?("foo.txt")).to be false
        expect(result[:outcome]).to eq("success")
        expect(result[:data]).to eq("File or dir deleted: 'foo.txt'")
      end

      it "notifies the agent and logs" do
        described_class.run(args: {"file_path" => "foo.txt", "intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • Deleting file or directory: 'foo.txt'")
        expect(status).to have_received(:verbose).with(" • File or dir deleted: 'foo.txt'")
        expect(logger).to have_received(:info).with("File or dir deleted: 'foo.txt'")
      end
    end

    context "when path does not exist" do
      it "returns success (rm_rf is idempotent)" do
        result = described_class.run(args: {"file_path" => "no_such", "intent" => described_class.name}, agent: agent)
        expect(result[:outcome]).to eq("success")
        expect(result[:data]).to eq("File or dir deleted: 'no_such'")
      end
    end

    context "when permission is denied" do
      before do
        allow(FileUtils).to receive(:rm_rf).and_raise(Errno::EACCES)
      end

      it "returns a permission denied error" do
        result = described_class.run(args: {"file_path" => "protected", "intent" => described_class.name}, agent: agent)
        expect(result[:outcome]).to eq("error")
        expect(result[:error]).to eq("Permission denied: protected")
      end
    end
  end
end
