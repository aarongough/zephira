# frozen_string_literal: true

require "readline"
require "json"
require "tty-spinner"
require "tty-screen"
require "tty-cursor"

module Zephira
  class Agent
    COMPACTION_TRIGGER_RATIO = 0.8
    COMPACTION_TARGET_RATIO = 0.5

    SYSTEM_PROMPT = <<~PROMPT
      You are a helpful command line agent called Zephira.
      You can run commands and tools to assist the user.
      You should make full use of the tools that are available to you.
      You can use the knowledge you already have to help the user, but if you don't know something, you should:
        - Use the tools available to you to find the answer
        - Ask the user for more information
        - Do not make up answers or pretend to know something you don't.

      Return all responses in a format that is easy to read in a terminal:
        - Do NOT return responses in Markdown format.
        - You can use unicode characters to make your output more readable.
        - You can use emojis to make your output more engaging (but don't overdo it).
        - You can use colors to highlight important information.
        - You can use formatting to make your output more readable.
        - You can return links to documentation or other resources as full URLs.

      You can use the following formatting tokens in your responses:
        - #{Formatter.available_formats.join("\n  - ")}

      If you are trying to perform operations that don't seem to be working,
      you should stop what you're doing and tell the user that you are unable
      to perform the operation, and tell the user why.

      When updating a file using the `update_file` tool, always output the complete file content — never partial content or diffs.

      You should not try to guess what the user is trying to do, or try to
      perform operations that are not explicitly requested by the user.

      Additional instructions provided by the user. The project-local instructions
      should overrule the global instructions:

      Global instructions (loaded from ~/.zephira/additional_instructions.md):
      @@@GLOBAL_ADDITIONAL_INSTRUCTIONS@@@

      Project instructions (loaded from ./.zephira/additional_instructions.md):
      @@@PROJECT_ADDITIONAL_INSTRUCTIONS@@@

      The user's current `date` is: @@@DATE@@@
      The user's current `uname -a` is: @@@UNAME@@@
      The user's current `pwd` is: @@@PWD@@@
      The user's current `ls -R` is: @@@LSR@@@
    PROMPT

    LOGO = <<~'LOGO'
      ░▒▓████████▓▒░░▒▓████████▓▒░░▒▓███████▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓███████▓▒░  ░▒▓██████▓▒░
           ░▒▓██▓▒░ ░▒▓█▓▒░       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
         ░▒▓██▓▒░   ░▒▓██████▓▒░  ░▒▓███████▓▒░ ░▒▓████████▓▒░░▒▓█▓▒░░▒▓███████▓▒░ ░▒▓████████▓▒░
       ░▒▓██▓▒░     ░▒▓█▓▒░       ░▒▓█▓▒░       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
      ░▒▓████████▓▒░░▒▓████████▓▒░░▒▓█▓▒░       ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
    LOGO

    attr_reader :history, :tools, :commands, :completions, :logger, :status
    attr_accessor :model, :verbose

    def initialize
      @verbose = false
      log_file_path = File.join(Dir.pwd, ".zephira", "session.log")
      @logger = Logger.new(file_path: log_file_path)
      @status = Status.new(self)
      @spinner = nil

      tool_dirs = [File.expand_path("tools", __dir__)]
      command_dirs = [File.expand_path("commands", __dir__)]
      completion_dirs = [File.expand_path("completions", __dir__)]

      @tools = Tools.load(paths: tool_dirs)
      @commands = Commands.load(paths: command_dirs)
      @completions = Completions.load(paths: completion_dirs)
      @history = History.new
      @history.compact_tool_messages!

      @uname = `uname -a`.strip
      @pwd = `pwd`.strip

      @model = resolve_model
    end

    def thinking(model_class)
      thinkmojis = %w[🤔 🧠 💭 🤯 🧐 ⏳ 🔄 🌀 🤨 💡 🧩 🔍 📚 ⚙️]
      token_count = Tokens.estimate(history.messages.to_json)
      update_status("Thinking... #{thinkmojis.shuffle.first} " + Formatter.color(:grey, "(#{model_class.model_name} - #{token_count} tokens)"))
    end

    def update_status(msg)
      @spinner&.spin
      puts msg
    end

    def run_tool(name:, args:)
      @tools.run(name: name, args: args, agent: self)
    end

    def run_command(name:, args:)
      @commands.run(name: name, args: args, agent: self)
    end

    def compact_history(force: false)
      current = Tokens.estimate(JSON.dump(@history.messages))
      threshold = (@model.context_limit * COMPACTION_TRIGGER_RATIO).to_i
      target = force ? [current / 2, 1].max : (@model.context_limit * COMPACTION_TARGET_RATIO).to_i

      return false if @history.messages.empty?
      return false if !force && current <= threshold

      puts Formatter.color(:grey, "  ✦ Compacting history (~#{current} tokens)...")
      @history.compact(
        response_model: @model,
        api_key: Config.read("ZEPHIRA_API_KEY"),
        agent: self,
        token_limit: target
      )
      after = Tokens.estimate(JSON.dump(@history.messages))
      puts Formatter.color(:grey, "  ✦ History compacted (~#{after} tokens).")
      true
    end

    def compact_if_needed
      compact_history(force: false)
    end

    def run_loop
      Readline.completion_proc = proc { |input| @completions.complete_all(input: input, agent: self) }
      seed_readline_history
      print_intro

      loop do
        render_status_bar

        user_input = Readline.readline("> ", true)
        break if user_input.nil?

        input = user_input.strip
        next if input.empty?

        TTY::Cursor.hide
        echo_user_input(input)

        if input.start_with?("/")
          dispatch_command(input)
          TTY::Cursor.show
          next
        end

        process_user_message(input)
        TTY::Cursor.show

        history.compact_tool_messages!
        compact_if_needed
      rescue Interrupt
        puts "\n[Interrupted]"
        break
      rescue => e
        puts "\nError: #{e.message}"
        logger.error("#{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
      end
    end

    def seed_readline_history
      return unless history.session_start > 0
      history.messages[0...history.session_start]
        .select { |message| message[:role] == "user" }
        .map { |message| message[:content] }
        .each { |command| Readline::HISTORY.push(command) }
    end

    def print_intro
      logo_width = LOGO.each_line.first.chomp.length
      logo_indent = [(screen_width - logo_width) / 2, 0].max
      puts Formatter.format(Formatter.color(:green, LOGO), indent: logo_indent)
      puts
      puts "#{Formatter.color(:grey, "System:")}\n Zephira starting... #{Formatter.color(:green, "Ready!")}"
      puts
      puts Formatter.color(:grey, "Zephira:")
      puts "  Hello! I am Zephira, your command line assistant. How can I help you today?"
      puts "  Type your command or question below. If you're not sure what to ask, you can"
      puts "  ask me what I can do for you... or type '/help' for a list of commands."
    end

    def render_status_bar
      context_used = Tokens.estimate(JSON.dump(@history.messages))
      context_limit = @model.context_limit
      # Percent of context window REMAINING (limit - used) / limit, clamped to 0..100.
      context_pct = ((context_limit - context_used).to_f / context_limit * 100).clamp(0, 100).to_i
      width = screen_width
      print TTY::Cursor.move_to(0, screen_height - 3)
      puts Formatter.color(:grey, "-" * width)

      sandbox_label = ENV["ZEPHIRA_IN_SANDBOX"] == "1" ? "sandboxed" : "⚠ DANGER: NO SANDBOX"
      sandbox_color = ENV["ZEPHIRA_IN_SANDBOX"] == "1" ? :green : :red
      right_text = "ctrl+c to exit | '/help' + enter to see commands | #{context_pct}% context left"
      padding = [width - sandbox_label.length - right_text.length, 1].max
      puts Formatter.color(sandbox_color, sandbox_label) + " " * padding + Formatter.color(:grey, right_text)
    end

    def echo_user_input(input)
      rows = screen_rows
      puts
      puts Formatter.color(:grey, "=" * screen_width)
      puts "\n" * rows
      print TTY::Cursor.up(rows)
      puts Formatter.color(:grey, "User:")
      puts Formatter.format(input, indent: 2)
      puts
    end

    def dispatch_command(input)
      parts = input[1..].strip.split
      run_command(name: parts.first, args: parts[1..] || [])
    end

    def process_user_message(input)
      history.append(role: "user", content: input)
      messages = [system_prompt] + history.messages.map { |message| message.slice(:role, :content, :tool_call_id, :tool_calls) }

      response = run_inference_with_spinner(messages)

      if response
        history.append(role: "assistant", content: response)
        puts Formatter.color(:grey, "\nZephira:")
        puts Formatter.format(response, indent: 2)
        puts
      end
    end

    def run_inference_with_spinner(messages)
      response = nil
      spinner_format_string = Formatter.color(:grey, "[") + Formatter.color(:green, " :spinner ") + Formatter.color(:grey, ":elapsed] ")
      @spinner = TTY::Spinner.new(spinner_format_string, format: :dots)
      spinner_started_at = Time.now
      @spinner.on(:spin) do
        elapsed = (Time.now - spinner_started_at).to_i
        @spinner.update(elapsed: sprintf("%03ds", elapsed))
      end

      @spinner.run(Formatter.color(:green, "Done!")) do
        response = @model.inference(
          api_key: Config.read("ZEPHIRA_API_KEY"),
          base_url: Config.read("ZEPHIRA_BASE_URL"),
          messages: messages,
          agent: self
        )
      end
      @spinner = nil
      response
    end

    private

    def load_additional_instructions
      instructions = {}
      global_file = File.join(Dir.home, ".zephira", "additional_instructions.md")
      project_file = File.join(Dir.pwd, ".zephira", "additional_instructions.md")
      instructions[:global] = File.read(global_file).strip if File.exist?(global_file)
      instructions[:project] = File.read(project_file).strip if File.exist?(project_file)
      instructions
    end

    def system_prompt
      instructions = load_additional_instructions
      {
        role: "system",
        content: SYSTEM_PROMPT
          .gsub("@@@GLOBAL_ADDITIONAL_INSTRUCTIONS@@@", instructions[:global] || "[NONE FOUND]")
          .gsub("@@@PROJECT_ADDITIONAL_INSTRUCTIONS@@@", instructions[:project] || "[NONE FOUND]")
          .gsub("@@@DATE@@@", `date`.strip)
          .gsub("@@@UNAME@@@", @uname)
          .gsub("@@@PWD@@@", @pwd)
          .gsub("@@@LSR@@@", `ls -R`.strip)
      }
    end

    def resolve_model
      name = Config.read("ZEPHIRA_MODEL") || "gpt-4.1-mini"
      Models.find_by_name(name) || Models::ChatGpt41Mini
    end

    def screen_width
      TTY::Screen.width
    rescue
      80
    end

    def screen_height
      TTY::Screen.height
    rescue
      24
    end

    def screen_rows
      TTY::Screen.rows
    rescue
      24
    end
  end
end
