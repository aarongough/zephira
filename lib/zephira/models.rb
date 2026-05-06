# frozen_string_literal: true

module Zephira
  module Models
    require_relative "models/base_model"
    Dir[File.join(__dir__, "models", "*.rb")].each { |f| require f }

    def self.available
      constants(false)
        .map { |const| const_get(const) }
        .reject { |c| c == BaseModel }
        .select { |c| c.respond_to?(:model_name) }
    end

    def self.find_by_name(name)
      available.find { |m| m.model_name.casecmp(name.to_s).zero? }
    end
  end
end
