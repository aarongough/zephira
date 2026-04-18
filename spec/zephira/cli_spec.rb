# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::CLI do
  let(:fake_agent) { instance_double(Zephira::Agent, run_loop: nil) }

  before do
    allow(Zephira::Agent).to receive(:new).and_return(fake_agent)
  end

  describe "cmd: zephira -v" do
    it "prints the version and exits" do
      expect { described_class.new(["-v"]) }
        .to output("#{Zephira::VERSION}\n").to_stdout.and raise_error(SystemExit)
    end
  end

  describe "cmd: zephira -h" do
    it "prints the help message and exits" do
      expect { described_class.new(["-h"]) }
        .to output(/Usage: zephira/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "cmd: zephira --unknown" do
    it "prints the help message and exits with an error" do
      expect { described_class.new(["--unknown"]) }
        .to output(/Usage: zephira/).to_stdout.and raise_error(SystemExit)
    end
  end

  describe "cmd: zephira" do
    it "builds the agent and starts the run loop" do
      described_class.new([])

      expect(Zephira::Agent).to have_received(:new)
      expect(fake_agent).to have_received(:run_loop)
    end
  end
end
