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

    it "delegates printing to the agent's update_status" do
      agent.verbose = true
      allow(agent).to receive(:update_status)
      agent.status.verbose("hello")
      expect(agent).to have_received(:update_status).with("hello")
    end

    it "skips update_status entirely when verbose is false" do
      agent.verbose = false
      allow(agent).to receive(:update_status)
      agent.status.verbose("nope")
      expect(agent).not_to have_received(:update_status)
    end
  end

  describe "interaction with the spinner during run_loop" do
    it "still prints warn output even when called rapidly" do
      messages = ["one", "two", "three"]
      output = messages.map { |msg| capture_stdout { agent.status.warn(msg) } }.join
      messages.each { |msg| expect(output).to include(msg) }
    end

    def capture_stdout
      original = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original
    end
  end
end
