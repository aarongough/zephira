# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::Compact do
  describe ".name" do
    it "returns 'compact'" do
      expect(described_class.name).to eq("compact")
    end
  end

  describe ".description" do
    it "returns a description string" do
      expect(described_class.description).to be_a(String)
    end
  end

  describe ".run" do
    let(:agent) { double("agent") }

    it "delegates to agent.compact_history with force: true" do
      allow(agent).to receive(:compact_history).with(force: true).and_return(true)
      described_class.run(agent: agent, args: [])
      expect(agent).to have_received(:compact_history).with(force: true)
    end

    it "prints 'Nothing to compact.' when no compaction occurred" do
      allow(agent).to receive(:compact_history).with(force: true).and_return(false)
      expect { described_class.run(agent: agent, args: []) }.to output(/Nothing to compact/).to_stdout
    end

    it "prints nothing when compaction occurred" do
      allow(agent).to receive(:compact_history).with(force: true).and_return(true)
      expect { described_class.run(agent: agent, args: []) }.not_to output(/Nothing/).to_stdout
    end
  end
end
