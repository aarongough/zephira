# frozen_string_literal: true

module Zephira
  module Backends
    Dir[File.join(__dir__, "backends", "*.rb")].each { |file| require file }

    def self.available
      constants(false)
        .map { |const| const_get(const) }
        .select { |const| const.respond_to?(:name) && const.name.is_a?(String) }
    end

    def self.find_by_name(identifier)
      available.find { |backend| backend.name == identifier }
    end
  end
end
