# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::MemoryDelete do
  include FakeFS::SpecHelpers

  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status) }
  let(:memory_path) { Zephira::Tools::MemoryDelete::MEMORY_PATH }

  describe ".parameters" do
    it "defines key and intent" do
      expect(described_class.parameters[:properties].keys).to contain_exactly(:key, :intent)
      expect(described_class.parameters[:required]).to contain_exactly("key", "intent")
    end
  end

  describe ".run" do
    context "argument validation" do
      it "errors when key is missing" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `key` must be supplied")
      end
    end

    context "when key exists" do
      before do
        FileUtils.mkdir_p(".zephira")
        File.write(memory_path, {"name" => "Alice", "keep" => "this"}.to_yaml)
      end

      it "removes the key and returns success" do
        result = described_class.run(args: {"key" => "name", "intent" => described_class.name}, agent: agent)
        expect(result).to be_success("Memory deleted: 'name'")
        memory = YAML.load_file(memory_path)
        expect(memory.key?("name")).to be false
        expect(memory["keep"]).to eq("this")
      end

      it "notifies the agent" do
        described_class.run(args: {"key" => "name", "intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • Memory deleted: 'name'")
      end
    end

    context "when key does not exist" do
      before do
        FileUtils.mkdir_p(".zephira")
        File.write(memory_path, {"other" => "value"}.to_yaml)
      end

      it "returns error" do
        result = described_class.run(args: {"key" => "missing", "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("Key not found: missing")
      end
    end

    context "when memory file does not exist" do
      it "returns error for any key" do
        result = described_class.run(args: {"key" => "anything", "intent" => described_class.name}, agent: agent)
        expect(result).to be_error("Key not found: anything")
      end
    end
  end
end
