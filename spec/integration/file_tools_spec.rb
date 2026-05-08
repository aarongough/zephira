# frozen_string_literal: true

require "spec_helper"

RSpec.describe "file tools", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)
  end

  let(:agent) { Zephira::Agent.new }

  def run_tool(name, args)
    agent.run_tool(name: name, args: args)
  end

  describe "read_file" do
    before { File.write("hello.rb", "puts 'hello'") }

    it "returns success" do
      result = run_tool("read_file", {file_paths: ["hello.rb"], intent: "read hello.rb"})
      expect(result).to be_success
    end

    it "returns an array of file hashes with content and path" do
      result = run_tool("read_file", {file_paths: ["hello.rb"], intent: "read hello.rb"})
      expect(result[:data].first).to include("content" => "puts 'hello'", "path" => "hello.rb")
    end

    it "can read multiple files at once" do
      File.write("other.rb", "puts 'other'")
      result = run_tool("read_file", {file_paths: ["hello.rb", "other.rb"], intent: "read both"})
      paths = result[:data].map { |f| f["path"] }
      expect(paths).to contain_exactly("hello.rb", "other.rb")
    end
  end

  describe "update_file" do
    it "creates a new file with the given content" do
      run_tool("update_file", {file_path: "new.rb", content: "# new file\n", intent: "create new.rb"})
      expect(File.read("new.rb")).to eq("# new file\n")
    end

    it "overwrites an existing file" do
      File.write("existing.rb", "old content")
      run_tool("update_file", {file_path: "existing.rb", content: "new content", intent: "overwrite existing.rb"})
      expect(File.read("existing.rb")).to eq("new content")
    end

    it "returns success" do
      result = run_tool("update_file", {file_path: "out.rb", content: "x", intent: "write out.rb"})
      expect(result).to be_success
    end
  end

  describe "list_directory" do
    before do
      File.write("a.rb", "")
      File.write("b.rb", "")
      FileUtils.mkdir_p("subdir")
    end

    it "lists files and directories" do
      result = run_tool("list_directory", {directory_path: ".", intent: "list ."})
      expect(result).to be_success
      expect(result[:data]).to include("a.rb", "b.rb")
    end

    it "returns an error for a missing directory" do
      result = run_tool("list_directory", {directory_path: "no_such_dir", intent: "list missing"})
      expect(result).to be_error(/Directory not found/)
    end
  end

  describe "delete_file" do
    before { File.write("doomed.rb", "bye") }

    it "deletes the file" do
      run_tool("delete_file", {file_path: "doomed.rb", intent: "delete doomed.rb"})
      expect(File.exist?("doomed.rb")).to be false
    end

    it "returns success" do
      result = run_tool("delete_file", {file_path: "doomed.rb", intent: "delete doomed.rb"})
      expect(result).to be_success
    end
  end
end
