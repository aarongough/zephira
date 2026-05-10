# frozen_string_literal: true

require_relative "zephira/version"
require_relative "zephira/config"
require_relative "zephira/sandbox"
require_relative "zephira/formatter"
require_relative "zephira/tokens"
require_relative "zephira/logger"
require_relative "zephira/backends"
require_relative "zephira/models"
require_relative "zephira/tools"
require_relative "zephira/tools/base_tool"
Dir[File.join(__dir__, "zephira/tools/*.rb")].each { |file| require file }
require_relative "zephira/history"
require_relative "zephira/commands"
Dir[File.join(__dir__, "zephira/commands/*.rb")].each { |file| require file }
require_relative "zephira/completions"
Dir[File.join(__dir__, "zephira/completions/*.rb")].each { |file| require file }
require_relative "zephira/agent"
require_relative "zephira/cli"

module Zephira
end
