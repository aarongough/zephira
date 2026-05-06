# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Completions::SlashCommands do
  let(:help_cmd) { double("help", name: "help") }
  let(:history_cmd) { double("history", name: "history") }
  let(:commands) { double("commands", constants: [help_cmd, history_cmd]) }
  let(:agent) { double("agent", commands: commands) }

  describe ".complete" do
    context "when input does not start with '/'" do
      it "returns empty array" do
        expect(described_class.complete(input: "help", agent: agent)).to eq([])
      end
    end

    context "when input starts with '/'" do
      it "returns matching command names with / prefix" do
        result = described_class.complete(input: "/hel", agent: agent)
        expect(result).to contain_exactly("/help")
      end

      it "returns all commands for '/'" do
        result = described_class.complete(input: "/", agent: agent)
        expect(result).to contain_exactly("/help", "/history")
      end

      it "returns empty for non-matching prefix" do
        expect(described_class.complete(input: "/xyz", agent: agent)).to eq([])
      end
    end
  end
end
