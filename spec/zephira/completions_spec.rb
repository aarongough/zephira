# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Completions do
  let(:completions) { described_class.new([]) }
  let(:agent) { double("agent") }

  describe "#constants" do
    it "returns loaded completion classes" do
      expect(completions.constants).to include(
        Zephira::Completions::FileNames,
        Zephira::Completions::SlashCommands
      )
    end
  end

  describe "#complete_all" do
    it "aggregates results from all completions and deduplicates" do
      allow(Zephira::Completions::FileNames).to receive(:complete).and_return(["@foo"])
      allow(Zephira::Completions::SlashCommands).to receive(:complete).and_return(["/help"])
      result = completions.complete_all(input: "/h", agent: agent)
      expect(result).to include("@foo", "/help")
    end
  end
end
