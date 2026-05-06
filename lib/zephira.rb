# frozen_string_literal: true

require_relative "zephira/version"
require_relative "zephira/config"
require_relative "zephira/formatter"
require_relative "zephira/logger"
require_relative "zephira/backends"
require_relative "zephira/models"
require_relative "zephira/tools"
require_relative "zephira/tools/base_tool"
Dir[File.join(__dir__, "zephira/tools/*.rb")].each { |f| require f }
require_relative "zephira/history"
require_relative "zephira/agent"
require_relative "zephira/cli"

require "yaml"
require "faraday"

module Zephira
end
