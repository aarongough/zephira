# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands do
  let(:commands) { described_class.new }

  describe "#constants" do
    it "returns all command classes" do
      names = commands.constants.map(&:name)
      expect(names).to include("help", "clear", "history", "model", "about", "bye")
    end
  end

  describe "#to_h" do
    it "returns name and description for each command" do
      result = commands.to_h
      expect(result).to all(include(:name, :description))
    end
  end

  describe "#run" do
    let(:agent) { double("agent") }

    it "delegates to the matching command class" do
      allow(Zephira::Commands::About).to receive(:run)
      commands.run(name: "about", args: [], agent: agent)
      expect(Zephira::Commands::About).to have_received(:run).with(agent: agent, args: [])
    end

    it "prints an error for unknown commands" do
      expect { commands.run(name: "nope", args: [], agent: agent) }
        .to output(/Unknown command/).to_stdout
    end
  end
end
