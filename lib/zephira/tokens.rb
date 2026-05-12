# frozen_string_literal: true

module Zephira
  # Approximates token counts for arbitrary text without pulling in a real
  # tokenizer dependency. Counts word-like runs and standalone punctuation,
  # which lands within ~20% of real BPE tokenizers (GPT/Claude) for English
  # text — close enough for context-budget decisions, never trust for billing.
  module Tokens
    TOKEN_PATTERN = /\w+|[^\s\w]/

    def self.estimate(text)
      return 0 if text.nil? || text.empty?
      text.to_s.scan(TOKEN_PATTERN).size
    end
  end
end
