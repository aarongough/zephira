# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::MemoryStore do
  include FakeFS::SpecHelpers

  describe ".load" do
    it "returns empty hash when no memory file exists" do
      expect(described_class.load).to eq({})
    end

    it "returns empty hash for empty file" do
      FileUtils.mkdir_p(File.dirname(described_class::PATH))
      File.write(described_class::PATH, "")
      expect(described_class.load).to eq({})
    end

    it "loads stored values" do
      FileUtils.mkdir_p(File.dirname(described_class::PATH))
      File.write(described_class::PATH, {"foo" => "bar"}.to_yaml)
      expect(described_class.load).to eq({"foo" => "bar"})
    end

    it "uses safe_load (refuses non-allowed classes)" do
      FileUtils.mkdir_p(File.dirname(described_class::PATH))
      File.write(described_class::PATH, "--- !ruby/object:Object {}\n")
      expect { described_class.load }.to raise_error(Psych::DisallowedClass)
    end
  end

  describe ".write and .read" do
    it "round-trips a value" do
      described_class.write("greeting", "hello")
      expect(described_class.read("greeting")).to eq("hello")
    end
  end

  describe ".delete" do
    it "removes a key and returns true" do
      described_class.write("k", "v")
      expect(described_class.delete("k")).to be true
      expect(described_class.key?("k")).to be false
    end

    it "returns false when key is absent" do
      expect(described_class.delete("missing")).to be false
    end
  end

  describe ".keys" do
    it "lists stored keys" do
      described_class.write("a", "1")
      described_class.write("b", "2")
      expect(described_class.keys).to contain_exactly("a", "b")
    end
  end
end
