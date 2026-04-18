# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Agent do
  describe "#initialize" do
    it "accepts keyword arguments" do
      expect { described_class.new(foo: "bar") }.not_to raise_error
    end
  end

  describe "#run_loop" do
    it "runs without error" do
      agent = described_class.new
      expect { agent.run_loop }.not_to raise_error
    end
  end
end
