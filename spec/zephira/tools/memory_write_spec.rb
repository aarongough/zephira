# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::MemoryWrite do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status, update_status: nil) }

  describe ".parameters" do
    it "defines key, value, and intent" do
      expect(described_class.parameters[:properties].keys).to contain_exactly(:key, :value, :intent)
      expect(described_class.parameters[:required]).to contain_exactly("key", "value", "intent")
    end
  end

  describe ".run" do
    context "argument validation" do
      it "errors when key is missing" do
        result = described_class.run(args: {"value" => "v", "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `key` must be supplied")
      end
    end

    context "when writing a new key" do
      it "creates memory file and returns success" do
        result = described_class.run(args: {"key" => "name", "value" => "Alice", "intent" => described_class.name}, agent: agent)
        expect(result).to be_success("Memory written: 'name'")
        memory = YAML.load_file(Zephira::Tools::MemoryWrite::MEMORY_PATH)
        expect(memory["name"]).to eq("Alice")
      end

      it "notifies the agent" do
        described_class.run(args: {"key" => "name", "value" => "Alice", "intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • Memory written: 'name'")
      end
    end

    context "when overwriting an existing key" do
      before do
        FileUtils.mkdir_p(".zephira")
        File.write(Zephira::Tools::MemoryWrite::MEMORY_PATH, {"name" => "old"}.to_yaml)
      end

      it "updates the value" do
        described_class.run(args: {"key" => "name", "value" => "new", "intent" => described_class.name}, agent: agent)
        memory = YAML.load_file(Zephira::Tools::MemoryWrite::MEMORY_PATH)
        expect(memory["name"]).to eq("new")
      end
    end

    context "when writing an empty value" do
      it "allows empty values" do
        result = described_class.run(args: {"key" => "empty", "value" => "", "intent" => described_class.name}, agent: agent)
        expect(result).to be_success
      end
    end
  end
end
