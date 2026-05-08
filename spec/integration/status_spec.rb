# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Agent::Status", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  describe "#warn" do
    it "always prints, regardless of verbose setting" do
      agent.verbose = false
      expect { agent.status.warn("something broke") }.to output(/something broke/).to_stdout
    end

    it "applies dark red color" do
      expect { agent.status.warn("oops") }.to output(/\e\[91m/).to_stdout
    end
  end

  describe "#verbose" do
    it "prints nothing when verbose is false" do
      agent.verbose = false
      expect { agent.status.verbose("detail") }.not_to output.to_stdout
    end

    it "prints when verbose is true" do
      agent.verbose = true
      expect { agent.status.verbose("detail") }.to output(/detail/).to_stdout
    end
  end
end
