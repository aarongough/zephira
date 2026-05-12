# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Sandbox do
  let(:default_image) { "ghcr.io/aarongough/zephira:#{Zephira::VERSION}" }

  before do
    allow(described_class).to receive(:container_runtime).and_return("docker")
    allow(described_class).to receive(:resolve_image).and_return(default_image)
    allow(Kernel).to receive(:exec)
    allow($stderr).to receive(:puts)
    ENV.delete("ZEPHIRA_IN_SANDBOX")
    ENV.delete("ZEPHIRA_SANDBOX")
  end

  after do
    ENV.delete("ZEPHIRA_IN_SANDBOX")
    ENV.delete("ZEPHIRA_SANDBOX")
  end

  describe ".exec_if_needed!" do
    context "when ZEPHIRA_IN_SANDBOX=1" do
      before { ENV["ZEPHIRA_IN_SANDBOX"] = "1" }

      it "returns without exec-ing" do
        described_class.exec_if_needed!([])
        expect(Kernel).not_to have_received(:exec)
      end
    end

    context "when ZEPHIRA_SANDBOX=false in env" do
      before { ENV["ZEPHIRA_SANDBOX"] = "false" }

      it "returns without exec-ing" do
        described_class.exec_if_needed!([])
        expect(Kernel).not_to have_received(:exec)
      end
    end

    context "when no supported container runtime is available" do
      before { allow(described_class).to receive(:container_runtime).and_return(nil) }

      it "exits with a non-zero status" do
        expect { described_class.exec_if_needed!([]) }.to raise_error(SystemExit)
      end

      it "prints instructions mentioning Docker and Podman to stderr" do
        begin
          described_class.exec_if_needed!([])
        rescue SystemExit
          nil
        end
        expect($stderr).to have_received(:puts).with(/Docker or Podman/)
      end

      it "prints instructions including --dangerously-skip-sandbox to stderr" do
        begin
          described_class.exec_if_needed!([])
        rescue SystemExit
          nil
        end
        expect($stderr).to have_received(:puts).with(/--dangerously-skip-sandbox/)
      end
    end

    context "when sandbox should activate with Docker" do
      before { allow(described_class).to receive(:container_runtime).and_return("docker") }

      def captured_exec_args(argv = ["--extra"])
        args = nil
        allow(Kernel).to receive(:exec) { |*a| args = a }
        described_class.exec_if_needed!(argv)
        args
      end

      it "calls Kernel.exec with docker run as the first two args" do
        described_class.exec_if_needed!([])
        expect(Kernel).to have_received(:exec).with("docker", "run", any_args)
      end

      it "includes --rm flag" do
        expect(captured_exec_args).to include("--rm")
      end

      it "includes the sentinel env var" do
        args = captured_exec_args
        idx = args.index("-e")
        expect(args[idx + 1]).to eq("ZEPHIRA_IN_SANDBOX=1")
      end

      it "mounts the current directory as /workspace" do
        expect(captured_exec_args).to include("#{Dir.pwd}:/workspace:rw")
      end

      it "sets the working directory to /workspace" do
        args = captured_exec_args
        idx = args.index("-w")
        expect(args[idx + 1]).to eq("/workspace")
      end

      it "uses the resolved image" do
        expect(captured_exec_args).to include(default_image)
      end

      it "passes argv through to the container" do
        args = captured_exec_args(["--verbose", "foo"])
        expect(args).to include("--verbose", "foo")
      end

      it "includes -t when stdout is a TTY" do
        allow($stdout).to receive(:tty?).and_return(true)
        expect(captured_exec_args).to include("-t")
      end

      it "omits -t when stdout is not a TTY" do
        allow($stdout).to receive(:tty?).and_return(false)
        expect(captured_exec_args).not_to include("-t")
      end

      it "forwards ZEPHIRA_-prefixed env vars" do
        ENV["ZEPHIRA_API_KEY"] = "test-key"
        expect(captured_exec_args).to include("ZEPHIRA_API_KEY=test-key")
      ensure
        ENV.delete("ZEPHIRA_API_KEY")
      end

      it "does not forward unrelated env vars" do
        ENV["SOME_RANDOM_VAR"] = "value"
        expect(captured_exec_args).not_to include(start_with("SOME_RANDOM_VAR="))
      ensure
        ENV.delete("SOME_RANDOM_VAR")
      end

      it "does not include unset env vars" do
        ENV.delete("ZEPHIRA_MODEL")
        expect(captured_exec_args).not_to include(start_with("ZEPHIRA_MODEL="))
      end
    end

    context "when sandbox should activate with Podman" do
      before { allow(described_class).to receive(:container_runtime).and_return("podman") }

      it "calls Kernel.exec with podman run as the first two args" do
        described_class.exec_if_needed!([])
        expect(Kernel).to have_received(:exec).with("podman", "run", any_args)
      end
    end
  end

  describe "forwarded_env_keys (private)" do
    it "excludes ZEPHIRA_IN_SANDBOX and ZEPHIRA_SANDBOX even if set" do
      ENV["ZEPHIRA_IN_SANDBOX"] = "1"
      ENV["ZEPHIRA_SANDBOX"] = "false"
      keys = described_class.send(:forwarded_env_keys)
      expect(keys).not_to include("ZEPHIRA_IN_SANDBOX", "ZEPHIRA_SANDBOX")
    ensure
      ENV.delete("ZEPHIRA_IN_SANDBOX")
      ENV.delete("ZEPHIRA_SANDBOX")
    end
  end

  describe "container_runtime (private)" do
    it "prefers Docker when both Docker and Podman are available" do
      allow(described_class).to receive(:runtime_available?).with("docker").and_return(true)
      allow(described_class).to receive(:runtime_available?).with("podman").and_return(true)

      expect(described_class.send(:container_runtime)).to eq("docker")
    end

    it "falls back to Podman when Docker is unavailable" do
      allow(described_class).to receive(:runtime_available?).with("docker").and_return(false)
      allow(described_class).to receive(:runtime_available?).with("podman").and_return(true)

      expect(described_class.send(:container_runtime)).to eq("podman")
    end

    it "returns nil when neither Docker nor Podman is available" do
      allow(described_class).to receive(:runtime_available?).with("docker").and_return(false)
      allow(described_class).to receive(:runtime_available?).with("podman").and_return(false)

      expect(described_class.send(:container_runtime)).to be_nil
    end
  end

  describe "resolve_image (private)" do
    before { allow(described_class).to receive(:resolve_image).and_call_original }

    context "without ZEPHIRA_BASE_IMAGE" do
      before { allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_IMAGE").and_return(nil) }

      it "returns the default GHCR image tagged with VERSION" do
        expect(described_class.send(:resolve_image, "docker")).to eq(default_image)
      end
    end

    context "with ZEPHIRA_BASE_IMAGE set" do
      before do
        allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_IMAGE").and_return("python:3.12-slim")
        allow(described_class).to receive(:image_exists?).and_return(true)
      end

      it "returns a derived image name containing the base image" do
        name = described_class.send(:resolve_image, "docker")
        expect(name).to start_with("zephira-sandbox-python-3.12-slim")
      end

      it "includes the Zephira version as the tag" do
        name = described_class.send(:resolve_image, "docker")
        expect(name).to end_with(":#{Zephira::VERSION}")
      end

      it "builds the derived image when it does not exist locally" do
        allow(described_class).to receive(:image_exists?).and_return(false)
        allow(described_class).to receive(:build_derived_image)
        described_class.send(:resolve_image, "docker")
        expect(described_class).to have_received(:build_derived_image).with("python:3.12-slim", kind_of(String), "docker")
      end

      it "skips building when the derived image already exists" do
        allow(described_class).to receive(:image_exists?).and_return(true)
        allow(described_class).to receive(:build_derived_image)
        described_class.send(:resolve_image, "docker")
        expect(described_class).not_to have_received(:build_derived_image)
      end
    end
  end

  describe "image_exists? (private)" do
    it "uses the selected runtime for image inspection" do
      allow(described_class).to receive(:system)
      described_class.send(:image_exists?, "my-image:tag", "podman")
      expect(described_class).to have_received(:system).with("podman image inspect my-image:tag > /dev/null 2>&1")
    end
  end

  describe "build_derived_image (private)" do
    it "uses the selected runtime for image builds" do
      allow(described_class).to receive(:system)
      described_class.send(:build_derived_image, "ruby:3.3", "zephira-test:#{Zephira::VERSION}", "podman")
      expect(described_class).to have_received(:system).with(match(/^podman build -t zephira-test:/))
    end
  end
end
