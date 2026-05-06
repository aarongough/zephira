# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::History do
  let(:agent) { double("agent", history: history) }

  describe ".run" do
    context "with messages" do
      let(:history) do
        double("history", messages: [
          {role: "user", content: "Hello", timestamp: "2025-01-01T00:00:00Z"},
          {role: "assistant", content: "Hi there", timestamp: "2025-01-01T00:00:01Z"}
        ])
      end

      it "prints each message with role and timestamp" do
        expect { described_class.run(agent: agent, args: []) }
          .to output(/user.*Hello/).to_stdout
      end
    end

    context "with a long message" do
      let(:long_content) { "x" * 200 }
      let(:history) do
        double("history", messages: [
          {role: "user", content: long_content, timestamp: "2025-01-01T00:00:00Z"}
        ])
      end

      it "truncates content to 100 chars" do
        output = capture_stdout { described_class.run(agent: agent, args: []) }
        printed_content = output.split(": ").last
        expect(printed_content.strip).to end_with("...")
        expect(printed_content.length).to be < long_content.length
      end
    end

    context "with no messages" do
      let(:history) { double("history", messages: []) }

      it "prints nothing" do
        expect { described_class.run(agent: agent, args: []) }
          .to output("").to_stdout
      end
    end
  end

  def capture_stdout
    out = StringIO.new
    $stdout = out
    yield
    out.string
  ensure
    $stdout = STDOUT
  end
end
