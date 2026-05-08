# frozen_string_literal: true

require "spec_helper"

RSpec.describe "history persistence", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  def new_agent
    Zephira::Agent.new
  end

  it "persists messages across agent restarts" do
    agent_a = new_agent
    agent_a.history.append(role: "user", content: "remember this")
    agent_a.history.append(role: "assistant", content: "I will remember.")

    agent_b = new_agent
    contents = agent_b.history.messages.map { |m| m[:content] }
    expect(contents).to include("remember this", "I will remember.")
  end

  it "marks session_start correctly for a fresh session after prior history" do
    agent_a = new_agent
    agent_a.history.append(role: "user", content: "first session")

    agent_b = new_agent
    expect(agent_b.history.session_start).to eq(1)
  end

  it "compacts tool messages on load so they don't inflate the context" do
    agent_a = new_agent
    agent_a.history.append(role: "user", content: "run a command")
    agent_a.history.append(role: "assistant", content: nil, tool_calls: [{id: "c1", type: "function", function: {name: "shell", arguments: "{}"}}])
    agent_a.history.append(role: "tool", tool_call_id: "c1", content: "output here")
    agent_a.history.append(role: "assistant", content: "Done.")

    agent_b = new_agent
    tool_msgs = agent_b.history.messages.select { |m| m[:role] == "tool" }
    expect(tool_msgs).to be_empty
  end

  it "starts with an empty history when no file exists" do
    agent = new_agent
    expect(agent.history.messages).to be_empty
    expect(agent.history.session_start).to eq(0)
  end
end
