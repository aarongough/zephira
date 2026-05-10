# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::ListDirectory do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", status: status, logger: logger, update_status: nil) }

  describe ".name" do
    it { expect(described_class.name).to eq("list_directory") }
  end

  describe ".parameters" do
    it "defines directory_path and intent" do
      expect(described_class.parameters[:properties].keys).to contain_exactly(:directory_path, :intent)
      expect(described_class.parameters[:required]).to contain_exactly("directory_path", "intent")
    end
  end

  describe ".run" do
    context "argument validation" do
      it "returns error if directory_path is missing" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_error("`directory_path` was empty or missing")
      end

      it "returns error if directory_path is empty string" do
        result = described_class.run(args: {"directory_path" => "", "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("`directory_path` was empty or missing")
      end
    end

    context "when directory exists" do
      before do
        FileUtils.mkdir_p("mydir")
        File.write("mydir/a.txt", "data1")
        File.write("mydir/b.txt", "data2")
      end

      it "returns success with directory entries" do
        result = described_class.run(args: {"directory_path" => "mydir", "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data]).to match_array(["a.txt", "b.txt"])
      end

      it "logs and notifies the agent" do
        described_class.run(args: {"directory_path" => "mydir", "intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • Listing directory contents: 'mydir'")
        expect(status).to have_received(:verbose).with(" • Directory contents listed: 2 entries in 'mydir'")
        expect(logger).to have_received(:info).with("Listing directory contents: 'mydir'")
      end
    end

    context "when directory does not exist" do
      it "returns error" do
        result = described_class.run(args: {"directory_path" => "no_dir", "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("Directory not found: 'no_dir'")
      end
    end

    context "when permission is denied" do
      before do
        allow(Dir).to receive(:children).and_raise(Errno::EACCES)
        FileUtils.mkdir_p("protected")
      end

      it "returns permission denied error" do
        result = described_class.run(args: {"directory_path" => "protected", "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("Permission denied: protected")
      end
    end
  end
end
