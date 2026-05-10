require "spec_helper"

RSpec.describe Zephira::Tools do
  let(:logger) { double(:logger, info: nil, warn: nil) }
  let(:status) { double(:status, verbose: nil, warn: nil) }
  let(:agent) { double(:agent, logger: logger, status: status, update_status: nil) }

  # Stub tool class registered directly into Zephira::Tools for isolation
  let(:stub_tool) do
    stub_const("Zephira::Tools::StubTool", Class.new(Zephira::Tools::BaseTool) do
      class << self
        def name = "stub_tool"
        def description = "A stub tool"
        def parameters = {type: "object", properties: {}}
      end

      def run
        success_result("stub result")
      end
    end)
  end

  let(:tools) { described_class.new }

  before { stub_tool }

  describe "#constants" do
    it "returns tool classes" do
      expect(tools.constants).to include(Zephira::Tools::StubTool)
    end

    it "excludes BaseTool" do
      expect(tools.constants).not_to include(Zephira::Tools::BaseTool)
    end

    it "excludes error classes" do
      expect(tools.constants).not_to include(
        Zephira::Tools::ToolNotFoundError,
        Zephira::Tools::ToolExecutionError,
        Zephira::Tools::ToolResultError
      )
    end
  end

  describe "#to_h" do
    it "returns an array of tool hashes with name, description, and parameters" do
      entry = tools.to_h.find { |tool| tool[:name] == "stub_tool" }
      expect(entry).to eq({
        name: "stub_tool",
        description: "A stub tool",
        parameters: {type: "object", properties: {}}
      })
    end
  end

  describe "#run" do
    context "when the tool is found and succeeds" do
      it "returns the tool result" do
        result = tools.run(name: "stub_tool", args: {intent: "test"}, agent: agent)
        expect(result).to be_success("stub result")
      end
    end

    context "when the tool is not found" do
      it "raises ToolNotFoundError" do
        expect {
          tools.run(name: "nonexistent", args: {intent: "test"}, agent: agent)
        }.to raise_error(Zephira::Tools::ToolNotFoundError, /Tool not found: nonexistent/)
      end
    end

    context "when the tool raises an exception" do
      before do
        allow(Zephira::Tools::StubTool).to receive(:run).and_raise(StandardError, "boom")
      end

      it "raises ToolExecutionError" do
        expect {
          tools.run(name: "stub_tool", args: {intent: "test"}, agent: agent)
        }.to raise_error(Zephira::Tools::ToolExecutionError, /boom/)
      end
    end

    context "when the tool returns an invalid result" do
      before do
        allow(Zephira::Tools::StubTool).to receive(:run).and_return({unexpected: true})
      end

      it "raises ToolResultError" do
        expect {
          tools.run(name: "stub_tool", args: {intent: "test"}, agent: agent)
        }.to raise_error(Zephira::Tools::ToolResultError, /Tool result must be a hash/)
      end
    end
  end
end
