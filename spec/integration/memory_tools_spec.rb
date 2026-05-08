# frozen_string_literal: true

require "spec_helper"

RSpec.describe "memory tools", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  def run_tool(name, args)
    agent.run_tool(name: name, args: args)
  end

  it "writes and reads a value" do
    run_tool("memory_write", {key: "color", value: "blue", intent: "store color"})
    result = run_tool("memory_read", {key: "color", intent: "read color"})
    expect(result).to be_success("blue")
  end

  it "lists stored keys" do
    run_tool("memory_write", {key: "x", value: "one", intent: "store x"})
    run_tool("memory_write", {key: "y", value: "two", intent: "store y"})
    result = run_tool("memory_list", {intent: "list keys"})
    expect(result[:data]).to include("x", "y")
  end

  it "deletes a key" do
    run_tool("memory_write", {key: "gone", value: "yes", intent: "store gone"})
    run_tool("memory_delete", {key: "gone", intent: "delete gone"})
    result = run_tool("memory_read", {key: "gone", intent: "check gone"})
    expect(result).to be_error(/Key not found/)
  end

  it "returns an error when reading a missing key" do
    result = run_tool("memory_read", {key: "no_such_key", intent: "read missing key"})
    expect(result).to be_error(/Key not found/)
  end

  it "persists across agent restarts" do
    run_tool("memory_write", {key: "persistent", value: "yes", intent: "store persistent"})
    agent2 = Zephira::Agent.new
    result = agent2.run_tool(name: "memory_read", args: {key: "persistent", intent: "read persistent"})
    expect(result).to be_success("yes")
  end
end
