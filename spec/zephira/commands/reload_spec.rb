# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::Reload do
  let(:agent) { double("agent") }

  before do
    allow(Kernel).to receive(:exec)
    stub_const("Zephira::ORIGINAL_ARGV", ["--flag"].freeze)
  end

  describe ".run" do
    it "prints a reloading message" do
      expect { described_class.run(agent: agent, args: []) }.to output(/Reloading/).to_stdout
    end

    context "when running under Bundler" do
      let(:gemfile) { "/tmp/Gemfile" }

      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:exist?).with(gemfile).and_return(true)
        stub_const("ENV", ENV.to_hash.merge("BUNDLE_GEMFILE" => gemfile))
      end

      it "execs through bundler" do
        described_class.run(agent: agent, args: [])
        expect(Kernel).to have_received(:exec).with("bundle", "exec", RbConfig.ruby, $PROGRAM_NAME, "--flag")
      end
    end

    context "when not running under Bundler" do
      before { stub_const("ENV", ENV.to_hash.reject { |key, _| key == "BUNDLE_GEMFILE" }) }

      it "execs Ruby directly" do
        described_class.run(agent: agent, args: [])
        expect(Kernel).to have_received(:exec).with(RbConfig.ruby, $PROGRAM_NAME, "--flag")
      end
    end
  end
end
