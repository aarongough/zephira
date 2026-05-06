# frozen_string_literal: true

module Zephira
  module Models
    class Llama4 < BaseModel
      def self.model_name
        "meta-llama/llama-4-maverick-17b-128e-instruct"
      end

      def self.context_limit
        131_072
      end
    end
  end
end
