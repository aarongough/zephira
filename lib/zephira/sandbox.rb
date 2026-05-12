# frozen_string_literal: true

require "tempfile"
require "io/console"

module Zephira
  class Sandbox
    GHCR_IMAGE = "ghcr.io/aarongough/zephira"
    DERIVED_IMAGE_PREFIX = "zephira-sandbox"
    CONTAINER_RUNTIMES = %w[docker podman].freeze
    SANDBOX_HOME = "/tmp/zephira-home"

    FORWARDED_ENV_PATTERNS = [/\AZEPHIRA_/].freeze
    FORWARDED_ENV_EXCLUDES = %w[ZEPHIRA_IN_SANDBOX ZEPHIRA_SANDBOX].freeze

    OUTER_TL = "╔"
    OUTER_TR = "╗"
    OUTER_BL = "╚"
    OUTER_BR = "╝"
    OUTER_H = "═"
    OUTER_V = "║"

    INNER_TL = "┌"
    INNER_TR = "┐"
    INNER_BL = "└"
    INNER_BR = "┘"
    INNER_H = "─"
    INNER_V = "│"
    INNER_PADDING = 3

    class << self
      def exec_if_needed!(argv)
        return if ENV["ZEPHIRA_IN_SANDBOX"] == "1"
        return if ENV["ZEPHIRA_SANDBOX"] == "false"

        runtime = container_runtime
        abort_with_sandbox_error unless runtime

        target = resolve_image(runtime)
        warn "[Zephira] Launching in #{runtime.capitalize} sandbox (#{target})..."
        Kernel.exec(*build_container_command(argv, target, runtime))
      end

      private

      def abort_with_sandbox_error
        width = terminal_width

        warn_lines = [
          "",
          "#{Formatter.color(:red, "⚠")}  #{Formatter.color(:red, "WARNING:")} Without the sandbox the agent has direct access to",
          "your host filesystem. Files it creates, modifies, or deletes",
          "affect your real system with no isolation or undo. Only skip",
          "the sandbox if you understand and accept this risk.",
          ""
        ]

        instruction_lines = [
          "",
          "  #{Formatter.color(:red, "ERROR:")} Zephira requires Docker or Podman to run safely in a sandboxed",
          "  environment.",
          "",
          "  Neither Docker nor Podman was found or currently running. To fix this:",
          "",
          "    1. Install Docker Desktop:  https://docs.docker.com/get-docker/",
          "       or install Podman:      https://podman.io/getting-started/installation",
          "    2. Start the runtime and confirm it is running:",
          "       docker info   or   podman info",
          "",
          "  To bypass the sandbox (not recommended):",
          "",
          "    zephira --dangerously-skip-sandbox",
          ""
        ]

        max_warn_width = warn_lines.map { |line| visible_length(line) }.max
        max_content_width = instruction_lines.map { |line| visible_length(line) }.max
        inner_width = [max_warn_width, max_content_width - 10].max

        inner_box = [
          "  " + inner_top(inner_width),
          *warn_lines.map { |line| "  " + inner_row(line, inner_width) },
          "  " + inner_bottom(inner_width)
        ]

        content = [*instruction_lines, *inner_box, ""]

        [
          outer_top(width),
          *content.map { |line| outer_row(line, width) },
          outer_bottom(width),
          ""
        ].each { |line| warn line }
        exit(1)
      end

      def outer_top(width)
        Formatter.color(:red, OUTER_TL + OUTER_H * (width - 2) + OUTER_TR)
      end

      def outer_bottom(width)
        Formatter.color(:red, OUTER_BL + OUTER_H * (width - 2) + OUTER_BR)
      end

      def outer_row(text, width)
        padding = " " * [width - 2 - visible_length(text), 0].max
        Formatter.color(:red, OUTER_V) + text + padding + Formatter.color(:red, OUTER_V)
      end

      def inner_top(max_width)
        Formatter.color(:red, INNER_TL + INNER_H * (max_width + INNER_PADDING * 2) + INNER_TR)
      end

      def inner_bottom(max_width)
        Formatter.color(:red, INNER_BL + INNER_H * (max_width + INNER_PADDING * 2) + INNER_BR)
      end

      def inner_row(text, max_width)
        padding = " " * [max_width - visible_length(text), 0].max
        pad = " " * INNER_PADDING
        Formatter.color(:red, INNER_V) + pad + text + padding + pad + Formatter.color(:red, INNER_V)
      end

      def visible_length(str)
        str.gsub(/\e\[[0-9;]*m/, "").length
      end

      def terminal_width
        IO.console&.winsize&.last || 80
      rescue
        80
      end

      def runtime_available?(binary)
        system("#{binary} info > /dev/null 2>&1")
      end

      def container_runtime
        CONTAINER_RUNTIMES.find { |runtime| runtime_available?(runtime) }
      end

      def resolve_image(runtime)
        base = Config.read("ZEPHIRA_BASE_IMAGE")
        return "#{GHCR_IMAGE}:#{VERSION}" unless base

        derived = derived_image_name(base)
        unless image_exists?(derived, runtime)
          warn "[Zephira] Building sandbox image from #{base} with #{runtime}..."
          build_derived_image(base, derived, runtime)
        end
        derived
      end

      def derived_image_name(base_image)
        sanitized = base_image.gsub(/[^a-zA-Z0-9._-]/, "-")
        "#{DERIVED_IMAGE_PREFIX}-#{sanitized}:#{VERSION}"
      end

      def image_exists?(name, runtime)
        system("#{runtime} image inspect #{name} > /dev/null 2>&1")
      end

      def build_derived_image(base_image, target_name, runtime)
        dockerfile = "FROM #{base_image}\nRUN gem install zephira:#{VERSION} --no-document\n"
        Tempfile.create(["zephira-sandbox", ".dockerfile"]) do |file|
          file.write(dockerfile)
          file.flush
          system("#{runtime} build -t #{target_name} -f #{file.path} .")
        end
      end

      def forwarded_env_keys
        ENV.keys
          .reject { |key| FORWARDED_ENV_EXCLUDES.include?(key) }
          .select { |key| FORWARDED_ENV_PATTERNS.any? { |pattern| key.match?(pattern) } }
          .sort
      end

      def build_container_command(argv, image, runtime)
        cmd = [runtime, "run", "--rm", "-i"]
        cmd << "-t" if $stdout.tty?

        cmd += ["--user", "#{Process.uid}:#{Process.gid}"]
        cmd += ["-e", "ZEPHIRA_IN_SANDBOX=1"]
        cmd += ["-e", "HOME=#{SANDBOX_HOME}"]
        cmd += ["-v", "#{Dir.pwd}:/workspace:rw"]
        cmd += ["-v", "#{sandbox_home_mount(runtime)}:#{SANDBOX_HOME}:rw"]

        global_config = File.expand_path("~/.zephira.yml")
        cmd += ["-v", "#{global_config}:#{SANDBOX_HOME}/.zephira.yml:ro"] if File.exist?(global_config)

        global_dir = File.expand_path("~/.zephira")
        cmd += ["-v", "#{global_dir}:#{SANDBOX_HOME}/.zephira:ro"] if File.exist?(global_dir) && File.directory?(global_dir)

        forwarded_env_keys.each do |key|
          cmd += ["-e", "#{key}=#{ENV[key]}"]
        end

        cmd += ["-w", "/workspace"]
        cmd << image
        cmd += ["zephira"] + argv
        cmd
      end

      def sandbox_home_mount(runtime)
        return "zephira-home-#{Process.uid}" if runtime == "docker"

        File.expand_path("~/.zephira/sandbox-home")
      end
    end
  end
end
