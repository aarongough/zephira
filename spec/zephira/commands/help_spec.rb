# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::Help do
  let(:fake_cmd) { double("cmd", name: "testcmd", description: "Does a thing") }
  let(:commands) { double("commands", constants: [fake_cmd]) }
  let(:agent) { double("agent", commands: commands) }

  describe ".run" do
    it "lists commands with names and descriptions" do
      expect { described_class.run(agent: agent, args: []) }
        .to output(%r{/testcmd: Does a thing}).to_stdout
    end

    it "prints a header" do
      expect { described_class.run(agent: agent, args: []) }
        .to output(/Available commands/).to_stdout
    end
  end
end
