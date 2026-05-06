# frozen_string_literal: true

module Zephira
  module Backends
    Dir[File.join(__dir__, "backends", "*.rb")].each { |f| require f }

    def self.available
      constants(false)
        .map { |const| const_get(const) }
        .select { |c| c.respond_to?(:name) && c.name.is_a?(String) }
    end

    def self.find_by_name(identifier)
      available.find { |c| c.name == identifier }
    end
  end
end
