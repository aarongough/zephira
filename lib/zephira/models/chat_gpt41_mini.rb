# frozen_string_literal: true

module Zephira
  module Models
    class ChatGpt41Mini < BaseModel
      def self.model_name
        "gpt-4.1-mini-2025-04-14"
      end

      def self.context_limit
        1_047_576
      end
    end
  end
end
