# frozen_string_literal: true

module Zephira
  module Models
    class Gpt55 < BaseModel
      def self.model_name
        "gpt-5.5"
      end

      def self.context_limit
        1_047_576
      end
    end
  end
end
