# frozen_string_literal: true

require "spec_helper"

RSpec.describe "tool call round-trip", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }
  let(:messages) { [agent.send(:system_prompt)] }

  def run_inference
    agent.model.inference(api_key: "test-key", base_url: nil, messages: messages, agent: agent)
  end

  it "returns a plain text response with no tool calls" do
    stub_chat(chat_text("Hello, world!"))
    expect(run_inference).to eq("Hello, world!")
  end

  it "returns nil when the response content is blank" do
    stub_chat(chat_text(nil))
    expect(run_inference).to be_nil
  end

  it "executes a tool call and returns the final text response" do
    stub_chat(
      chat_tool_call(name: "shell", args: {command: "echo hello", intent: "echo hello"}),
      chat_text("The command ran successfully.")
    )
    expect(run_inference).to eq("The command ran successfully.")
  end

  it "appends the tool result to history" do
    stub_chat(
      chat_tool_call(name: "shell", args: {command: "echo hello", intent: "echo hello"}),
      chat_text("Done.")
    )
    run_inference
    tool_msgs = agent.history.messages.select { |message| message[:role] == "tool" }
    expect(tool_msgs.first[:content]).to include("hello")
  end

  it "handles a nil final content after tool call" do
    stub_chat(
      chat_tool_call(name: "shell", args: {command: "echo hi", intent: "echo hi"}),
      chat_text(nil)
    )
    expect(run_inference).to be_nil
  end

  it "reports an error when a required tool argument is missing" do
    stub_chat(
      chat_tool_call(name: "shell", args: {command: "echo hi"}),
      chat_text("Done.")
    )
    run_inference
    tool_msgs = agent.history.messages.select { |message| message[:role] == "tool" }
    expect(tool_msgs.first[:content]).to include("must be supplied")
  end

  it "chains multiple tool calls before returning the final response" do
    stub_chat(
      chat_tool_call(name: "shell", args: {command: "echo first", intent: "first call"}, id: "c1"),
      chat_tool_call(name: "shell", args: {command: "echo second", intent: "second call"}, id: "c2"),
      chat_text("All done.")
    )
    result = run_inference
    expect(result).to eq("All done.")
    tool_msgs = agent.history.messages.select { |message| message[:role] == "tool" }
    expect(tool_msgs.size).to eq(2)
  end
end
