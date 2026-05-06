# frozen_string_literal: true

module Zephira
  module Models
    class GptO4Mini < BaseModel
      def self.model_name
        "o4-mini-2025-04-16"
      end

      def self.context_limit
        200_000
      end
    end
  end
end
