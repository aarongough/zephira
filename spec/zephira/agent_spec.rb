# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Agent do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { described_class.new }

  describe "#initialize" do
    it "creates a History" do
      expect(agent.history).to be_a(Zephira::History)
    end

    it "loads Tools" do
      expect(agent.tools).to be_a(Zephira::Tools)
    end

    it "loads Commands" do
      expect(agent.commands).to be_a(Zephira::Commands)
    end

    it "loads Completions" do
      expect(agent.completions).to be_a(Zephira::Completions)
    end

    it "creates a Logger" do
      expect(agent.logger).to be_a(Zephira::Logger)
    end

    it "creates a Status" do
      expect(agent.status).to be_a(Zephira::Agent::Status)
    end

    it "sets a model class" do
      expect(agent.model).to respond_to(:inference)
    end

    it "resolves the model by name" do
      allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("claude-3-5-sonnet-20241022")
      agent = described_class.new
      expect(agent.model.model_name).to eq("claude-3-5-sonnet-20241022")
    end

    it "falls back to ChatGpt41Mini for unknown model names" do
      allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("no-such-model")
      agent = described_class.new
      expect(agent.model).to eq(Zephira::Models::ChatGpt41Mini)
    end

    it "defaults verbose to false" do
      expect(agent.verbose).to be false
    end
  end

  describe "#verbose?" do
    it "returns false by default" do
      expect(agent.verbose?).to be false
    end

    it "returns true when verbose is set" do
      agent.verbose = true
      expect(agent.verbose?).to be true
    end
  end

  describe "#thinking" do
    let(:model_class) { double("model", model_name: "test-model", context_limit: 100_000) }

    it "prints a status line including the model name" do
      expect { agent.thinking(model_class) }.to output(/test-model/).to_stdout
    end

    it "includes a thinking emoji" do
      expect { agent.thinking(model_class) }.to output(/Thinking/).to_stdout
    end
  end

  describe "#update_status" do
    it "prints the message" do
      expect { agent.update_status("hello") }.to output(/hello/).to_stdout
    end
  end

  describe "#run_tool" do
    it "delegates to tools" do
      allow(agent.tools).to receive(:run).and_return({outcome: "success", error: nil, data: "ok"})
      agent.run_tool(name: "shell", args: {command: "echo hi"})
      expect(agent.tools).to have_received(:run).with(name: "shell", args: {command: "echo hi"}, agent: agent)
    end
  end

  describe "#run_command" do
    it "delegates to commands" do
      allow(agent.commands).to receive(:run)
      agent.run_command(name: "help", args: [])
      expect(agent.commands).to have_received(:run).with(name: "help", args: [], agent: agent)
    end
  end

  describe "#compact_history" do
    it "returns false when below threshold and not forced" do
      expect(agent.compact_history(force: false)).to be false
    end

    it "returns false when history is empty even when forced" do
      expect(agent.compact_history(force: true)).to be false
    end

    it "delegates to history.compact when forced and non-empty" do
      agent.history.append(role: "user", content: "hello world this is content")
      allow(agent.history).to receive(:compact)
      expect { agent.compact_history(force: true) }.to output(/Compacting/).to_stdout
      expect(agent.history).to have_received(:compact)
    end

    it "skips compaction when below auto-trigger threshold" do
      agent.history.append(role: "user", content: "tiny")
      allow(agent.history).to receive(:compact)
      agent.compact_history(force: false)
      expect(agent.history).not_to have_received(:compact)
    end
  end

  describe "#run_loop" do
    before do
      allow(Readline).to receive(:completion_proc=)
      allow(Readline).to receive(:readline).and_return(nil)
      allow(TTY::Screen).to receive(:width).and_return(80)
      allow(TTY::Screen).to receive(:height).and_return(24)
      allow(TTY::Screen).to receive(:rows).and_return(24)
      allow(TTY::Cursor).to receive(:hide)
      allow(TTY::Cursor).to receive(:show)
      allow(TTY::Cursor).to receive(:up).and_return("")
    end

    def stub_spinner
      spinner = instance_double(TTY::Spinner)
      allow(TTY::Spinner).to receive(:new).and_return(spinner)
      allow(spinner).to receive(:on)
      allow(spinner).to receive(:run) { |_, &block| block&.call }
      spinner
    end

    it "exits cleanly when readline returns nil (EOF)" do
      expect { agent.run_loop }.not_to raise_error
    end

    it "skips blank input" do
      allow(Readline).to receive(:readline).and_return("   ", nil)
      allow(agent.model).to receive(:inference)
      agent.run_loop
      expect(agent.model).not_to have_received(:inference)
    end

    it "dispatches slash commands" do
      allow(Readline).to receive(:readline).and_return("/help", nil)
      allow(agent.commands).to receive(:run)
      agent.run_loop
      expect(agent.commands).to have_received(:run).with(name: "help", args: [], agent: agent)
    end

    it "calls inference for plain user input" do
      stub_spinner
      allow(Readline).to receive(:readline).and_return("hello", nil)
      allow(agent.model).to receive(:inference).and_return("Hi there!")
      agent.run_loop
      expect(agent.model).to have_received(:inference)
    end

    it "prints the response" do
      stub_spinner
      allow(Readline).to receive(:readline).and_return("hello", nil)
      allow(agent.model).to receive(:inference).and_return("Hi there!")
      expect { agent.run_loop }.to output(/Hi there!/).to_stdout
    end

    it "displays the logo on startup" do
      expect { agent.run_loop }.to output(/ZEPHIRA|░▒▓/).to_stdout
    end

    it "displays a greeting message" do
      expect { agent.run_loop }.to output(/Hello! I am Zephira/).to_stdout
    end

    it "handles errors without crashing" do
      stub_spinner
      allow(Readline).to receive(:readline).and_return("hello", nil)
      allow(agent.model).to receive(:inference).and_raise(RuntimeError, "boom")
      expect { agent.run_loop }.not_to raise_error
    end
  end
end
