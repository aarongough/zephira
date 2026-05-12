# frozen_string_literal: true

require "io/console"
require "yaml"

module Zephira
  class Onboarding
    GLOBAL_CONFIG_PATH = File.expand_path("~/.zephira.yml")

    OUTER_TL = "╔"
    OUTER_TR = "╗"
    OUTER_BL = "╚"
    OUTER_BR = "╝"
    OUTER_H = "═"
    OUTER_V = "║"

    class << self
      def run_if_needed!
        return if ENV["ZEPHIRA_IN_SANDBOX"] == "1"
        return unless Config.read("ZEPHIRA_API_KEY").to_s.empty?

        unless $stdin.tty?
          print_no_tty_error
          exit(1)
        end

        print_welcome
        key = prompt_key
        if key.nil? || key.empty?
          print_cancelled
          exit(1)
        end

        write_config!(key)
        print_success
      end

      private

      def prompt_key
        print "  OpenAI API key: "
        raw = $stdin.noecho(&:gets)
        puts
        return nil if raw.nil?
        stripped = raw.strip
        stripped.empty? ? nil : stripped
      rescue Interrupt
        puts
        nil
      end

      def write_config!(key)
        existing = File.exist?(GLOBAL_CONFIG_PATH) ? (YAML.load_file(GLOBAL_CONFIG_PATH) || {}) : {}
        merged = existing.merge("ZEPHIRA_API_KEY" => key)
        File.write(GLOBAL_CONFIG_PATH, YAML.dump(merged))
        File.chmod(0o600, GLOBAL_CONFIG_PATH)
      end

      def print_welcome
        lines = [
          "",
          "  #{Formatter.color(:green, Formatter.style(:bold, "Welcome to Zephira"))}",
          "",
          "  Zephira talks to OpenAI by default. Paste your OpenAI API key below",
          "  and we'll save it to ~/.zephira.yml for future runs.",
          "",
          "  To target a different OpenAI-compatible endpoint instead, cancel and",
          "  set ZEPHIRA_BASE_URL alongside your key in ~/.zephira.yml.",
          "",
          "  Input is hidden. Press Enter on an empty line to cancel.",
          ""
        ]
        render_box(lines, :green)
        puts
      end

      def print_success
        puts
        puts "  #{Formatter.color(:green, "✓")} Saved API key to #{GLOBAL_CONFIG_PATH}"
        puts
      end

      def print_cancelled
        puts
        puts "  #{Formatter.color(:grey, "Cancelled.")} Set ZEPHIRA_API_KEY in your environment"
        puts "  or populate ~/.zephira.yml to skip onboarding."
        puts
      end

      def print_no_tty_error
        warn ""
        warn "  #{Formatter.color(:red, "ERROR:")} Zephira needs an OpenAI API key, but stdin is not a TTY."
        warn ""
        warn "  Set ZEPHIRA_API_KEY in your environment, or populate"
        warn "  ~/.zephira.yml with:"
        warn ""
        warn "    ZEPHIRA_API_KEY: \"sk-...\""
        warn ""
      end

      def render_box(lines, color)
        width = box_width(lines)
        puts Formatter.color(color, OUTER_TL + OUTER_H * (width - 2) + OUTER_TR)
        lines.each { |line| puts box_row(line, width, color) }
        puts Formatter.color(color, OUTER_BL + OUTER_H * (width - 2) + OUTER_BR)
      end

      def box_row(text, width, color)
        padding = " " * [width - 2 - visible_length(text), 0].max
        Formatter.color(color, OUTER_V) + text + padding + Formatter.color(color, OUTER_V)
      end

      def box_width(lines)
        content_max = lines.map { |line| visible_length(line) }.max || 0
        desired = content_max + 4
        [desired, terminal_width].min.then { |target| [target, content_max + 4].max }
      end

      def visible_length(str)
        str.gsub(/\e\[[0-9;]*m/, "").length
      end

      def terminal_width
        IO.console&.winsize&.last || 80
      rescue
        80
      end
    end
  end
end
