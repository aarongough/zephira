# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tokens do
  describe ".estimate" do
    it "returns 0 for nil" do
      expect(described_class.estimate(nil)).to eq(0)
    end

    it "returns 0 for empty string" do
      expect(described_class.estimate("")).to eq(0)
    end

    it "counts each word as a token" do
      expect(described_class.estimate("hello world")).to eq(2)
    end

    it "counts punctuation as separate tokens" do
      expect(described_class.estimate("hello, world!")).to eq(4)
    end

    it "coerces non-string input via to_s" do
      expect(described_class.estimate(:foo)).to eq(1)
    end

    it "ignores whitespace" do
      expect(described_class.estimate("   \n\t  ")).to eq(0)
    end
  end
end
