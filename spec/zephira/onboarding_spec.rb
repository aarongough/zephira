# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Onboarding do
  include FakeFS::SpecHelpers

  let(:config_path) { File.expand_path("~/.zephira.yml") }

  before do
    ENV.delete("ZEPHIRA_IN_SANDBOX")
    FileUtils.mkdir_p(File.dirname(config_path))
    allow($stdin).to receive(:tty?).and_return(true)
    allow($stdin).to receive(:noecho)
    allow(described_class).to receive(:puts)
    allow(described_class).to receive(:print)
    allow(described_class).to receive(:warn)
  end

  after { ENV.delete("ZEPHIRA_IN_SANDBOX") }

  def stub_key_input(value)
    allow($stdin).to receive(:noecho).and_return(value.nil? ? nil : "#{value}\n")
  end

  describe ".run_if_needed!" do
    context "when ZEPHIRA_IN_SANDBOX=1" do
      before { ENV["ZEPHIRA_IN_SANDBOX"] = "1" }

      it "returns without prompting" do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return(nil)
        described_class.run_if_needed!
        expect($stdin).not_to have_received(:noecho)
      end
    end

    context "when the API key is already configured" do
      before { allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("sk-existing") }

      it "returns without prompting" do
        described_class.run_if_needed!
        expect($stdin).not_to have_received(:noecho)
      end
    end

    context "when the API key is an empty string" do
      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("")
        stub_key_input("sk-new")
      end

      it "still triggers onboarding" do
        described_class.run_if_needed!
        expect($stdin).to have_received(:noecho)
      end
    end

    context "when the API key is missing and stdin is not a TTY" do
      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return(nil)
        allow($stdin).to receive(:tty?).and_return(false)
      end

      it "exits non-zero without prompting" do
        expect { described_class.run_if_needed! }.to raise_error(SystemExit)
        expect($stdin).not_to have_received(:noecho)
      end
    end

    context "when the API key is missing and the user cancels with empty input" do
      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return(nil)
        stub_key_input("")
      end

      it "exits non-zero" do
        expect { described_class.run_if_needed! }.to raise_error(SystemExit)
      end
    end

    context "when the API key is missing and SIGINT is raised during input" do
      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return(nil)
        allow($stdin).to receive(:noecho).and_raise(Interrupt)
      end

      it "exits non-zero" do
        expect { described_class.run_if_needed! }.to raise_error(SystemExit)
      end
    end

    context "when the API key is missing and the user provides one" do
      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return(nil)
        stub_key_input("sk-fresh")
      end

      it "writes the key to ~/.zephira.yml" do
        described_class.run_if_needed!
        expect(YAML.load_file(config_path)["ZEPHIRA_API_KEY"]).to eq("sk-fresh")
      end

      it "creates the file with 0600 permissions" do
        described_class.run_if_needed!
        expect(File.stat(config_path).mode & 0o777).to eq(0o600)
      end

      it "trims surrounding whitespace from the entered key" do
        stub_key_input("  sk-padded  ")
        described_class.run_if_needed!
        expect(YAML.load_file(config_path)["ZEPHIRA_API_KEY"]).to eq("sk-padded")
      end

      it "preserves existing unrelated keys when merging" do
        File.write(config_path, YAML.dump({"ZEPHIRA_BRAVE_SEARCH_API_KEY" => "brave-secret"}))
        described_class.run_if_needed!
        saved = YAML.load_file(config_path)
        expect(saved["ZEPHIRA_API_KEY"]).to eq("sk-fresh")
        expect(saved["ZEPHIRA_BRAVE_SEARCH_API_KEY"]).to eq("brave-secret")
      end
    end
  end
end
