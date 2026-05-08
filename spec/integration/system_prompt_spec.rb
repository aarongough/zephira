# frozen_string_literal: true

require "spec_helper"

RSpec.describe "system_prompt", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  subject(:content) { agent.send(:system_prompt)[:content] }

  it "has role 'system'" do
    expect(agent.send(:system_prompt)[:role]).to eq("system")
  end

  it "substitutes date" do
    expect(content).to match(/The user's current `date` is: \S/)
  end

  it "substitutes uname" do
    expect(content).to match(/The user's current `uname -a` is: \S/)
  end

  it "substitutes pwd" do
    expect(content).to match(/The user's current `pwd` is: \S/)
  end

  it "substitutes ls -R" do
    expect(content).to include("The user's current `ls -R` is:")
  end

  it "includes formatting tokens from Formatter" do
    expect(content).to include("##COLOR_GREEN##")
  end

  it "labels global and project instruction sections" do
    expect(content).to include("Global instructions (loaded from ~/.zephira/additional_instructions.md):")
    expect(content).to include("Project instructions (loaded from ./.zephira/additional_instructions.md):")
  end

  it "shows NONE FOUND when no instruction files exist" do
    expect(content).to include("[NONE FOUND]")
  end

  context "with a global instructions file" do
    before do
      FileUtils.mkdir_p(File.join(Dir.home, ".zephira"))
      File.write(File.join(Dir.home, ".zephira", "additional_instructions.md"), "Always be concise.")
    end

    it "includes the global instructions" do
      expect(content).to include("Always be concise.")
    end
  end

  context "with a project instructions file" do
    before do
      FileUtils.mkdir_p(File.join(Dir.pwd, ".zephira"))
      File.write(File.join(Dir.pwd, ".zephira", "additional_instructions.md"), "Use Ruby style guide.")
    end

    it "includes the project instructions" do
      expect(content).to include("Use Ruby style guide.")
    end
  end
end
