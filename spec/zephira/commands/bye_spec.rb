# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::Bye do
  let(:agent) { double("agent") }

  describe ".run" do
    it "exits the process" do
      expect { described_class.run(agent: agent, args: []) }.to raise_error(SystemExit)
    end

    it "prints a goodbye message before exiting" do
      expect do
        described_class.run(agent: agent, args: [])
      rescue SystemExit
      end.to output(/Bye/).to_stdout
    end
  end
end
