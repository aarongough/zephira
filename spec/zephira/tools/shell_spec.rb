# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe Zephira::Tools::Shell do
  let(:workdir) { Dir.pwd }
  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", status: status, logger: logger, update_status: nil) }

  before do
    allow(described_class).to receive(:terminal_width).and_return(described_class::TRUNCATION_LIMIT)
  end

  describe ".run" do
    context "argument validation" do
      it "errors when command is missing or empty" do
        result = described_class.run(args: {"intent" => described_class.name}, agent: agent)
        expect(result).to be_error("argument `command` must be supplied")
      end
    end

    context "when command succeeds" do
      let(:stdout_str) { "output\n" }
      let(:stderr_str) { "" }
      let(:exit_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }

      before do
        allow(Open3).to receive(:capture3).and_return([stdout_str, stderr_str, exit_status])
      end

      it "executes the command" do
        described_class.run(args: {"command" => "echo hello", "intent" => described_class.name}, agent: agent)
        expect(Open3).to have_received(:capture3).with("echo hello", chdir: workdir)
      end

      it "returns success with stdout, stderr, and exit status" do
        result = described_class.run(args: {"command" => "echo hello", "intent" => described_class.name}, agent: agent)
        expect(result[:outcome]).to eq("success")
        expect(result[:data]).to eq({status: 0, stdout: stdout_str, stderr: stderr_str})
      end

      it "updates the agent status" do
        described_class.run(args: {"command" => "echo hello", "intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • Running shell command: 'echo hello'")
        expect(status).to have_received(:verbose).with(" • Shell command stdout: output ")
        expect(status).to have_received(:verbose).with(" • Shell command completed with exit status: 0")
      end
    end

    context "when command fails with stderr" do
      let(:stdout_str) { "" }
      let(:stderr_str) { "something went wrong\n" }
      let(:exit_status) { instance_double(Process::Status, success?: false, exitstatus: 3) }

      before do
        allow(Open3).to receive(:capture3).and_return([stdout_str, stderr_str, exit_status])
      end

      it "returns success with non-zero exit status" do
        result = described_class.run(args: {"command" => "false", "intent" => described_class.name}, agent: agent)
        expect(result[:outcome]).to eq("success")
        expect(result[:data]).to eq({status: 3, stdout: stdout_str, stderr: stderr_str})
      end

      it "emits stderr in agent status" do
        described_class.run(args: {"command" => "false", "intent" => described_class.name}, agent: agent)
        expect(status).to have_received(:verbose).with(" • \e[91mShell command stderr:\e[0m something went wrong ")
      end
    end

    context "when command is not found" do
      before do
        allow(Open3).to receive(:capture3).and_raise(Errno::ENOENT)
      end

      it "returns an error outcome" do
        result = described_class.run(args: {"command" => "nonexistent", "intent" => described_class.name}, agent: agent)
        expect(result[:outcome]).to eq("error")
        expect(result[:error]).to eq("Command not found: nonexistent")
        expect(result[:data]).to be_nil
      end
    end

    context "when output exceeds truncation limit" do
      let(:many_lines) { (1..50).map { |i| "line#{i}" }.join("\n") + "\n" }
      let(:exit_status) { instance_double(Process::Status, success?: true, exitstatus: 0) }

      before do
        allow(described_class).to receive(:terminal_width).and_return(described_class::TRUNCATION_LIMIT + 50)
        allow(Open3).to receive(:capture3).and_return([many_lines, "", exit_status])
      end

      it "truncates and appends remaining line count" do
        described_class.run(args: {"command" => "generate", "intent" => described_class.name}, agent: agent)
        formatted = many_lines.tr("\n", " ")[0, Zephira::Tools::Shell::TRUNCATION_LIMIT - 19]
        remaining = many_lines.lines.size - 1
        expected = " • Shell command stdout: #{formatted} ... (~#{remaining} more lines)"
        expect(status).to have_received(:verbose).with(expected)
      end
    end
  end
end
