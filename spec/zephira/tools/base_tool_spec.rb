require "spec_helper"

RSpec.describe Zephira::Tools::BaseTool do
  let(:logger) { double(:logger, info: nil, warn: nil) }
  let(:status) { double(:status, verbose: nil, warn: nil) }
  let(:agent) { double(:agent, logger: logger, status: status) }

  # A minimal concrete tool for testing
  let(:tool_class) do
    stub_const("TestTool", Class.new(described_class) do
      class << self
        def name = "test_tool"
        def description = "A test tool"
        def parameters = {type: "object", properties: {}}
      end

      def run
        success_result("it worked")
      end
    end)
  end

  describe ".as_json" do
    it "returns the function JSON definition" do
      expect(tool_class.as_json).to eq({
        type: "function",
        function: {
          name: "test_tool",
          description: "A test tool",
          parameters: {type: "object", properties: {}}
        }
      })
    end
  end

  describe ".run" do
    context "when intent is missing" do
      it "returns an error result" do
        result = tool_class.run(args: {}, agent: agent)
        expect(result).to be_error("argument `args[:intent]` must be supplied")
      end
    end

    context "when intent is blank" do
      it "returns an error result" do
        result = tool_class.run(args: {intent: "  "}, agent: agent)
        expect(result).to be_error("argument `args[:intent]` must be of type String and non-empty")
      end
    end

    context "when intent is provided and run succeeds" do
      it "returns the success result" do
        result = tool_class.run(args: {intent: "do a thing"}, agent: agent)
        expect(result).to be_success("it worked")
      end

      it "logs the success" do
        tool_class.run(args: {intent: "do a thing"}, agent: agent)
        expect(logger).to have_received(:info).with(/completed successfully/)
        expect(status).to have_received(:verbose).with(/completed successfully/)
      end
    end

    context "when run raises an exception" do
      let(:tool_class) do
        stub_const("ErrorTool", Class.new(described_class) do
          class << self
            def name = "error_tool"
            def description = "A tool that raises"
            def parameters = {}
          end

          def run
            raise "something went wrong"
          end
        end)
      end

      it "returns an error result" do
        result = tool_class.run(args: {intent: "do a thing"}, agent: agent)
        expect(result).to be_error("something went wrong")
      end

      it "logs the error" do
        tool_class.run(args: {intent: "do a thing"}, agent: agent)
        expect(logger).to have_received(:warn).with(/returned error/)
        expect(status).to have_received(:warn).with(/ERROR:/)
      end
    end
  end

  describe "#arg" do
    it "retrieves args by symbol key" do
      instance = described_class.new(args: {intent: "test"}, agent: agent)
      expect(instance.arg(:intent)).to eq("test")
    end

    it "retrieves args by string key" do
      instance = described_class.new(args: {"intent" => "test"}, agent: agent)
      expect(instance.arg(:intent)).to eq("test")
    end
  end

  describe "#validate" do
    let(:instance) { described_class.new(args: {}, agent: agent) }

    it "raises ToolUseError when value is nil and allow_nil is false" do
      expect {
        instance.validate(nil, arg_path: "foo", type: String)
      }.to raise_error(described_class::ToolUseError, /must be supplied/)
    end

    it "raises ToolUseError when value is blank string" do
      expect {
        instance.validate("  ", arg_path: "foo", type: String)
      }.to raise_error(described_class::ToolUseError, /non-empty/)
    end

    it "returns the value when valid" do
      expect(instance.validate("hello", arg_path: "foo", type: String)).to eq("hello")
    end
  end
end
