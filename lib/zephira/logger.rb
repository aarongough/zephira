# frozen_string_literal: true

require "fileutils"

module Zephira
  class Logger
    LOG_LEVELS = %i[debug info warn error].freeze

    attr_reader :logfile, :log_level

    def initialize(file_path:, log_level: :debug)
      FileUtils.mkdir_p(File.dirname(file_path))
      @logfile = File.open(file_path, "a")
      @log_level = log_level

      raise ArgumentError, "Invalid log level: #{log_level}" unless LOG_LEVELS.include?(log_level)
    end

    def debug(message, **args)
      log(:debug, message, **args)
    end

    def info(message, **args)
      log(:info, message, **args)
    end

    def error(message, **args)
      log(:error, message, **args)
    end

    def warn(message, **args)
      log(:warn, message, **args)
    end

    def log(level, message, **args)
      return unless should_log?(level)

      @logfile.puts "#{Time.now} - #{level.to_s.strip.upcase} - #{message} - #{args.inspect}"
      @logfile.flush
    end

    def should_log?(level)
      LOG_LEVELS.index(level) >= LOG_LEVELS.index(@log_level)
    end
  end
end
