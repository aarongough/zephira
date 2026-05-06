# frozen_string_literal: true

module Zephira
  module Models
    class Claude35Sonnet < BaseModel
      def self.model_name
        "claude-3-5-sonnet-20241022"
      end

      def self.context_limit
        200_000
      end
    end
  end
end
