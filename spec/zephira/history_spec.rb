require "spec_helper"
require "time"

RSpec.describe Zephira::History do
  include FakeFS::SpecHelpers

  let(:frozen_time) { Time.parse("2025-05-01T12:00:00Z") }

  before do
    allow(Time).to receive(:now).and_return(frozen_time)
  end

  describe "#initialize" do
    it "defaults to an empty messages array" do
      expect(described_class.new.messages).to eq([])
    end

    it "can be initialized with existing messages and writes them to disk" do
      initial = [{role: "user", content: "Hello"}]
      hist = described_class.new(initial)
      expect(hist.messages).to eq(initial)
      file = File.join(Dir.pwd, ".zephira", "history.jsonl")
      lines = File.read(file).lines.map { |l| JSON.parse(l, symbolize_names: true) }
      expect(lines).to eq([{role: "user", content: "Hello"}])
    end

    it "loads from disk when initialized with no messages and a history file exists" do
      storage_dir = File.join(Dir.pwd, ".zephira")
      FileUtils.mkdir_p(storage_dir)
      entries = [
        {role: "user", content: "A", timestamp: frozen_time.iso8601},
        {role: "assistant", content: "B", timestamp: frozen_time.iso8601}
      ]
      File.open(File.join(storage_dir, "history.jsonl"), "w") do |f|
        entries.each { |e| f.puts JSON.generate(e) }
      end

      expect(described_class.new.messages).to eq(entries)
    end

    it "sets session_start to the number of pre-existing messages" do
      initial = [{role: "user", content: "prev", timestamp: frozen_time.iso8601}]
      hist = described_class.new(initial)
      expect(hist.session_start).to eq(1)
    end
  end

  describe "#append" do
    it "adds a message to history in memory and on disk" do
      hist = described_class.new
      hist.append(role: "user", content: "Hello")
      expect(hist.messages.size).to eq(1)
      file = File.join(Dir.pwd, ".zephira", "history.jsonl")
      lines = File.read(file).lines.map { |l| JSON.parse(l, symbolize_names: true) }
      expect(lines.first[:content]).to eq("Hello")
    end
  end

  describe "#clear" do
    it "clears messages in memory and on disk" do
      hist = described_class.new
      hist.append(role: "user", content: "Hello")
      hist.clear
      expect(hist.messages).to be_empty
      file = File.join(Dir.pwd, ".zephira", "history.jsonl")
      expect(File.read(file)).to be_empty
    end
  end

  describe "#clear_session" do
    it "removes only messages added in the current session" do
      initial = [
        {role: "user", content: "prev1", timestamp: frozen_time.iso8601},
        {role: "assistant", content: "prev2", timestamp: frozen_time.iso8601}
      ]
      hist = described_class.new(initial)
      hist.append(role: "user", content: "new1")
      hist.append(role: "assistant", content: "new2")

      hist.clear_session

      expect(hist.messages.map { |m| m[:content] }).to eq(["prev1", "prev2"])
    end
  end

  describe "#compact_tool_messages!" do
    it "replaces assistant tool_calls messages with a summary and persists" do
      hist = described_class.new
      hist.append(role: "user", content: "ask")
      tool_call = {function: {name: "foo_tool", arguments: JSON.generate({intent: "demo intent"})}}
      hist.append(role: "assistant", content: "invoke tool", tool_calls: [tool_call])
      hist.append(role: "assistant", content: "after")

      hist.compact_tool_messages!

      expect(hist.messages.map { |m| m[:role] }).not_to include("tool")
      summary = hist.messages.find { |m| m[:content] =~ /Agent used tool/ }
      expect(summary[:content]).to eq("Agent used tool(s):\n\n- `foo_tool` with intent `demo intent`")
      file = File.join(Dir.pwd, ".zephira", "history.jsonl")
      lines = File.read(file).lines.map { |l| JSON.parse(l, symbolize_names: true) }
      expect(lines.map { |e| e[:content] }).to include("Agent used tool(s):\n\n- `foo_tool` with intent `demo intent`")
    end

    it "combines multiple tool calls from one assistant message into a single summary" do
      hist = described_class.new
      hist.append(role: "user", content: "ask multiple")
      tool_call1 = {function: {name: "alpha_tool", arguments: JSON.generate({intent: "first intent"})}}
      tool_call2 = {function: {name: "beta_tool", arguments: JSON.generate({intent: "second intent"})}}
      hist.append(role: "assistant", content: "invoke both", tool_calls: [tool_call1, tool_call2])

      hist.compact_tool_messages!

      assistant_msgs = hist.messages.select { |m| m[:role] == "assistant" }
      expect(assistant_msgs.size).to eq(1)
      expect(assistant_msgs.first[:content]).to eq(
        "Agent used tool(s):\n\n- `alpha_tool` with intent `first intent`\n- `beta_tool` with intent `second intent`"
      )
    end
  end

  describe "#compact" do
    let(:response_model) { double("model", simple_inference: "summary text") }

    it "summarizes chunks when token count exceeds the limit and prepends a system summary" do
      hist = described_class.new
      50.times { |i| hist.append(role: "user", content: "m#{i}") }

      hist.compact(response_model: response_model, api_key: "test-key", token_limit: 10)

      expect(hist.messages.first[:role]).to eq("system")
      expect(hist.messages.first[:content]).to start_with("[Summary")
      expect(hist.messages.size).to eq(14)
    end

    it "does nothing when token count is under the limit" do
      hist = described_class.new
      hist.append(role: "user", content: "short")

      hist.compact(response_model: response_model, api_key: "test-key", token_limit: 10)

      expect(hist.messages.first[:content]).to eq("short")
    end
  end

  describe "#size" do
    it "returns the approximate token count across all messages" do
      hist = described_class.new
      hist.append(role: "user", content: "Hello this is a test")
      hist.append(role: "assistant", content: "Hi thanks for the test")

      expect(hist.size).to eq(10)
    end
  end
end
