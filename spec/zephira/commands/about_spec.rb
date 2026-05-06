# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::About do
  let(:agent) { double("agent") }

  describe ".run" do
    it "prints version information" do
      expect { described_class.run(agent: agent, args: []) }
        .to output(/Zephira.*#{Zephira::VERSION}/m).to_stdout
    end
  end
end
