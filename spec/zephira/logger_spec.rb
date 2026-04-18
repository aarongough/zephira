# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Zephira::Logger do
  let(:file_path) { File.join("logs", "test.log") }

  around do |example|
    FakeFS.with_fresh do
      example.run
    end
  end

  describe "#initialize" do
    it "creates the directory for the log file" do
      expect {
        described_class.new(file_path: file_path)
      }.to change { Dir.exist?(File.dirname(file_path)) }.from(false).to(true)
    end

    it "creates the log file" do
      expect {
        described_class.new(file_path: file_path)
      }.to change { File.exist?(file_path) }.from(false).to(true)
    end

    it "accepts a log level" do
      logger = described_class.new(file_path: file_path, log_level: :warn)
      expect(logger.instance_variable_get(:@log_level)).to eq(:warn)
    end

    it "defaults to :debug log level" do
      logger = described_class.new(file_path: file_path)
      expect(logger.log_level).to eq(:debug)
    end

    it "raies an error for invalid log level" do
      expect {
        described_class.new(file_path: file_path, log_level: :invalid)
      }.to raise_error(ArgumentError, "Invalid log level: invalid")
    end
  end

  describe "#should_log?" do
    context "when the log level is set to :debug" do
      let(:logger) { described_class.new(file_path: file_path, log_level: :debug) }

      it "returns true for all log levels" do
        expect(logger.should_log?(:debug)).to be true
        expect(logger.should_log?(:info)).to be true
        expect(logger.should_log?(:warn)).to be true
        expect(logger.should_log?(:error)).to be true
      end
    end

    context "when the log level is set to :info" do
      let(:logger) { described_class.new(file_path: file_path, log_level: :info) }

      it "returns true for :info, :warn, and :error" do
        expect(logger.should_log?(:info)).to be true
        expect(logger.should_log?(:warn)).to be true
        expect(logger.should_log?(:error)).to be true
        expect(logger.should_log?(:debug)).to be false
      end
    end

    context "when the log level is set to :warn" do
      let(:logger) { described_class.new(file_path: file_path, log_level: :warn) }

      it "returns true for :warn and :error" do
        expect(logger.should_log?(:warn)).to be true
        expect(logger.should_log?(:error)).to be true
        expect(logger.should_log?(:info)).to be false
        expect(logger.should_log?(:debug)).to be false
      end
    end

    context "when the log level is set to :error" do
      let(:logger) { described_class.new(file_path: file_path, log_level: :error) }

      it "returns true only for :error" do
        expect(logger.should_log?(:error)).to be true
        expect(logger.should_log?(:warn)).to be false
        expect(logger.should_log?(:info)).to be false
        expect(logger.should_log?(:debug)).to be false
      end
    end
  end

  describe "#log" do
    let(:logger) { described_class.new(file_path: file_path) }
    let(:fixed_time) { Time.new(2023, 1, 1) }

    before do
      allow(Time).to receive(:now).and_return(fixed_time)
    end

    it "logs a message with the log level" do
      logger.log(:info, "Info message")
      expect(File.read(file_path)).to include("#{fixed_time} - INFO - Info message - {}")
    end

    it "appends to the log file" do
      logger.log(:info, "Info message")
      logger.log(:warn, "Warn message")
      expect(File.read(file_path)).to include("#{fixed_time} - INFO - Info message - {}")
      expect(File.read(file_path)).to include("#{fixed_time} - WARN - Warn message - {}")
    end

    it "correctly outputs log data" do
      logger.log(:debug, "Debug message", key: "value", foo: ["array", "of", "values"], blah: "string")

      file_content = File.read(file_path)
      expect(file_content).to include("#{fixed_time} - DEBUG - Debug message")
      expect(file_content).to include("{key: \"value\", foo: [\"array\", \"of\", \"values\"], blah: \"string\"}")
    end

    it "logs nothing if the log level is below the logger's log level" do
      logger = described_class.new(file_path: file_path, log_level: :warn)
      logger.log(:info, "Info message")
      logger.log(:debug, "Debug message")
      logger.log(:warn, "Warn message")
      logger.log(:error, "Error message")

      expect(File.read(file_path)).not_to include("Info message")
      expect(File.read(file_path)).not_to include("Debug message")
      expect(File.read(file_path)).to include("Warn message")
      expect(File.read(file_path)).to include("Error message")
    end
  end

  describe "forwarding of log level methods" do
    let(:logger) { described_class.new(file_path: file_path) }

    before do
      allow(logger).to receive(:log)
    end

    it "forwards debug to log(:debug, ...)" do
      logger.debug("Debug message", key: "value")
      expect(logger).to have_received(:log).with(:debug, "Debug message", key: "value")
    end

    it "forwards info to log(:info, ...)" do
      logger.info("Info message", key: "value")
      expect(logger).to have_received(:log).with(:info, "Info message", key: "value")
    end

    it "forwards warn to log(:warn, ...)" do
      logger.warn("Warn message", key: "value")
      expect(logger).to have_received(:log).with(:warn, "Warn message", key: "value")
    end

    it "forwards error to log(:error, ...)" do
      logger.error("Error message", key: "value")
      expect(logger).to have_received(:log).with(:error, "Error message", key: "value")
    end
  end
end
