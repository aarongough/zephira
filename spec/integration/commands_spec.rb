# frozen_string_literal: true

require "spec_helper"

RSpec.describe "commands dispatch", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  def run_command(name, args = [])
    agent.run_command(name: name, args: args)
  end

  describe "/help" do
    it "prints a list of available commands" do
      expect { run_command("help") }.to output(/\/help/).to_stdout
    end

    it "includes all registered commands" do
      output = capture_stdout { run_command("help") }
      %w[help history clear bye about model].each do |cmd|
        expect(output).to include("/#{cmd}")
      end
    end
  end

  describe "/about" do
    it "prints the version" do
      expect { run_command("about") }.to output(/#{Regexp.escape(Zephira::VERSION)}/o).to_stdout
    end

    it "prints the name" do
      expect { run_command("about") }.to output(/Zephira/).to_stdout
    end
  end

  describe "/history" do
    it "prints nothing when history is empty" do
      expect { run_command("history") }.not_to output(/role/).to_stdout
    end

    it "prints each message after some turns" do
      agent.history.append(role: "user", content: "hello there")
      expect { run_command("history") }.to output(/hello there/).to_stdout
    end
  end

  describe "/clear" do
    before do
      agent.history.append(role: "user", content: "old message")
    end

    it "clears session messages with 'session'" do
      run_command("clear", ["session"])
      session_messages = agent.history.messages[agent.history.session_start..]
      expect(session_messages).to be_empty
    end

    it "clears all messages with 'all'" do
      run_command("clear", ["all"])
      expect(agent.history.messages).to be_empty
    end

    it "prints usage when no argument given" do
      expect { run_command("clear") }.to output(/Usage/).to_stdout
    end
  end

  describe "/model" do
    it "lists available models" do
      expect { run_command("model") }.to output(/gpt-4.1-mini/).to_stdout
    end

    it "shows which model is active" do
      expect { run_command("model") }.to output(/\*|active|current/i).to_stdout
    end

    it "changes the model with 'set MODEL'" do
      run_command("model", ["set", "claude-3-5-sonnet-20241022"])
      expect(agent.model.model_name).to eq("claude-3-5-sonnet-20241022")
    end

    it "prints an error for an unknown model name" do
      expect { run_command("model", ["set", "no-such-model"]) }.to output(/not found|unknown/i).to_stdout
    end
  end

  describe "/bye" do
    it "exits the process" do
      expect { run_command("bye") }.to raise_error(SystemExit)
    end
  end

  describe "unknown command" do
    it "prints an error message" do
      expect { run_command("nonexistent") }.to output(/Unknown command/).to_stdout
    end
  end
end
