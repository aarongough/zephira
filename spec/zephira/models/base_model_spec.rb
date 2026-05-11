require "spec_helper"

RSpec.describe Zephira::Models::BaseModel do
  let(:logger) { instance_double(Zephira::Logger, info: nil, error: nil, debug: nil) }
  let(:history) { double("History", append: nil) }
  let(:tools) { double("Tools", to_h: [], read_only?: false) }
  let(:agent) do
    double("Agent",
      logger: logger,
      history: history,
      tools: tools,
      thinking: nil,
      run_tool: {outcome: "success", error: nil, data: "ok"})
  end

  let(:mock_backend) { double("Backend") }

  before do
    allow(Zephira::Backends::OpenAiCompatible).to receive(:new).and_return(mock_backend)
  end

  describe ".model_name / .context_limit" do
    it "raises NotImplementedError for model_name" do
      expect { described_class.model_name }.to raise_error(NotImplementedError)
    end

    it "raises NotImplementedError for context_limit" do
      expect { described_class.context_limit }.to raise_error(NotImplementedError)
    end
  end

  describe ".backend_class" do
    it "defaults to OpenAiCompatible" do
      expect(described_class.backend_class).to eq(Zephira::Backends::OpenAiCompatible)
    end

    it "returns a named backend when ZEPHIRA_BACKEND is set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ZEPHIRA_BACKEND").and_return("openai_compatible")
      allow(Zephira::Backends).to receive(:find_by_name).with("openai_compatible")
        .and_return(Zephira::Backends::OpenAiCompatible)

      expect(described_class.backend_class).to eq(Zephira::Backends::OpenAiCompatible)
    end
  end

  describe ".format_tools" do
    let(:tool) do
      {name: "shell", description: "Run a shell command", parameters: {type: "object", properties: {}}}
    end
    let(:tools) { double("Tools", to_h: [tool], read_only?: false) }

    it "formats a tool into a function definition" do
      result = described_class.format_tools(tools)
      expect(result.first[:type]).to eq("function")
      expect(result.first[:function][:name]).to eq("shell")
      expect(result.first[:function][:description]).to eq("Run a shell command")
      expect(result.first[:function][:parameters]).to eq(tool[:parameters])
    end
  end

  describe ".simple_inference" do
    it "calls chat and returns the content" do
      allow(mock_backend).to receive(:chat).and_return({"content" => "summary"})

      result = Zephira::Models::GptO4Mini.simple_inference(
        api_key: "key",
        messages: [{role: "user", content: "summarize"}]
      )
      expect(result).to eq("summary")
    end
  end

  describe ".inference" do
    context "when the model returns a plain text response" do
      it "returns the response content" do
        allow(mock_backend).to receive(:chat).and_return({"content" => "Hello!", "tool_calls" => nil})

        result = Zephira::Models::GptO4Mini.inference(
          api_key: "key",
          agent: agent,
          messages: [{role: "user", content: "hi"}]
        )
        expect(result).to eq("Hello!")
      end

      it "returns nil when content is empty" do
        allow(mock_backend).to receive(:chat).and_return({"content" => ""})

        result = Zephira::Models::GptO4Mini.inference(
          api_key: "key",
          agent: agent,
          messages: [{role: "user", content: "hi"}]
        )
        expect(result).to be_nil
      end
    end

    context "when the model returns tool calls" do
      let(:tool_call) do
        {
          "type" => "function",
          "id" => "call_123",
          "function" => {"name" => "shell", "arguments" => '{"command":"ls","intent":"list"}'}
        }
      end

      it "executes tools and recurses until a plain response is returned" do
        allow(mock_backend).to receive(:chat).and_return(
          {"content" => nil, "tool_calls" => [tool_call]},
          {"content" => "Done!", "tool_calls" => nil}
        )

        result = Zephira::Models::GptO4Mini.inference(
          api_key: "key",
          agent: agent,
          messages: [{role: "user", content: "run ls"}]
        )
        expect(result).to eq("Done!")
        expect(agent).to have_received(:run_tool).with(name: "shell", args: {command: "ls", intent: "list"})
      end
    end
  end

  describe ".dispatch_tool_calls" do
    let(:read_only_call) do
      {"id" => "ro1", "function" => {"name" => "read_file", "arguments" => '{"file_paths":["a"]}'}}
    end
    let(:mutating_call) do
      {"id" => "m1", "function" => {"name" => "shell", "arguments" => '{"command":"ls"}'}}
    end

    before do
      allow(tools).to receive(:read_only?) { |name| name == "read_file" }
    end

    it "preserves the original ordering of tool calls in returned results" do
      allow(agent).to receive(:run_tool).and_return({outcome: "success", error: nil, data: "ok"})
      results = described_class.dispatch_tool_calls([mutating_call, read_only_call], agent: agent)
      expect(results.map { |call, _| call["id"] }).to eq(["m1", "ro1"])
    end

    it "runs read-only tools concurrently" do
      received_threads = []
      mutex = Mutex.new
      allow(agent).to receive(:run_tool) do
        mutex.synchronize { received_threads << Thread.current }
        {outcome: "success", error: nil, data: "ok"}
      end

      ro_a = read_only_call.merge("id" => "a")
      ro_b = read_only_call.merge("id" => "b")
      described_class.dispatch_tool_calls([ro_a, ro_b], agent: agent)

      expect(received_threads.uniq.size).to be > 1
    end

    it "runs mutating tools on the calling thread (sequentially)" do
      seen_threads = []
      allow(agent).to receive(:run_tool) do
        seen_threads << Thread.current
        {outcome: "success", error: nil, data: "ok"}
      end
      described_class.dispatch_tool_calls([mutating_call, mutating_call.merge("id" => "m2")], agent: agent)
      expect(seen_threads).to all(eq(Thread.current))
    end
  end
end
