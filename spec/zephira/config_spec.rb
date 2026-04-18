# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Config do
  include FakeFS::SpecHelpers

  describe ".read" do
    before do
      ENV.delete("ZEPHIRA_TEST_KEY")
      FakeFS.activate!
    end

    after do      
      FakeFS.deactivate!
    end

    def create_project_config(key: "ZEPHIRA_TEST_KEY", value: "project_key")
      File.write(".zephira.yml", "#{key}: #{value}", mode: "a")
    end

    def create_global_config(key: "ZEPHIRA_TEST_KEY", value: "global_key")
      FileUtils.mkdir_p(File.expand_path("~"))
      File.write(File.expand_path("~/.zephira.yml"), "#{key}: #{value}", mode: "a")
    end

    context "when only the environment variable is set" do
      it "returns the value of the environment variable" do
        ENV["ZEPHIRA_TEST_KEY"] = "env_test_key"
        expect(described_class.read("ZEPHIRA_TEST_KEY")).to eq("env_test_key")
      end
    end

    context "when only the project-level config file exists" do
      it "returns the value from the project-level config file" do
        create_project_config
        expect(described_class.read("ZEPHIRA_TEST_KEY")).to eq("project_key")
      end
    end

    context "when only the global config file exists" do
      it "returns the value from the global config file" do
        create_global_config
        expect(described_class.read("ZEPHIRA_TEST_KEY")).to eq("global_key")
      end
    end

    context "when the project config exists but does not contain the key" do
      it "returns nil" do
        create_project_config(key: "OTHER_KEY")
        expect(described_class.read("ZEPHIRA_TEST_KEY")).to be_nil
      end
    end

    context "when the global config exists but does not contain the key" do
      it "returns nil" do
        create_global_config(key: "OTHER_KEY")
        expect(described_class.read("ZEPHIRA_TEST_KEY")).to be_nil
      end
    end

    context "when both project-level and global config files exist and have the key" do
      it "returns the value from the project-level config file (overriding global)" do
        create_global_config
        create_project_config

        expect(described_class.read("ZEPHIRA_TEST_KEY")).to eq("project_key")
      end
    end

    context "when the environment variable is set and there are config files with the same key" do
      it "returns the value from the environment variable (overriding config files)" do
        ENV["ZEPHIRA_TEST_KEY"] = "env_test_key"
        create_global_config
        create_project_config

        expect(described_class.read("ZEPHIRA_TEST_KEY")).to eq("env_test_key")
      end
    end

    context "when neither environment variable nor config files are set" do
      it "returns nil" do
        expect(described_class.read("ZEPHIRA_TEST_KEY")).to be_nil
      end
    end
  end
end
