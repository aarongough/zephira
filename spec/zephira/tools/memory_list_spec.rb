# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::MemoryList do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status, update_status: nil) }
  let(:memory_path) { Zephira::Tools::MemoryList::MEMORY_PATH }

  describe ".parameters" do
    it "defines only intent" do
      expect(described_class.parameters[:properties].keys).to contain_exactly(:intent)
      expect(described_class.parameters[:required]).to contain_exactly("intent")
    end
  end

  describe ".run" do
    context "when memory has entries" do
      before do
        FileUtils.mkdir_p(".zephira")
        File.write(memory_path, {"name" => "Alice", "project" => "Zephira"}.to_yaml)
      end

      it "returns list of keys" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_success
        expect(result[:data]).to match_array(["name", "project"])
      end

      it "notifies the agent with count" do
        described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • Memory list: 2 keys")
      end
    end

    context "when memory file does not exist" do
      it "returns empty list" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_success([])
      end
    end

    context "when memory file is empty" do
      before do
        FileUtils.mkdir_p(".zephira")
        File.write(memory_path, {}.to_yaml)
      end

      it "returns empty list" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_success([])
      end
    end
  end
end
