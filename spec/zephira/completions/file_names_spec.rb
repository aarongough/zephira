# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Completions::FileNames do
  let(:agent) { double("agent") }

  before do
    allow(Dir).to receive(:glob).with("foo*").and_return(["foo.rb"])
    allow(Dir).to receive(:glob).with("baz*").and_return(["baz"])
    allow(Dir).to receive(:glob).with("*").and_return(["foo.rb", "bar.rb", "baz"])
    allow(File).to receive(:directory?).with("foo.rb").and_return(false)
    allow(File).to receive(:directory?).with("bar.rb").and_return(false)
    allow(File).to receive(:directory?).with("baz").and_return(true)
  end

  describe ".complete" do
    context "when input does not start with '@'" do
      it "returns empty array" do
        expect(described_class.complete(input: "hello", agent: agent)).to eq([])
      end
    end

    context "when input starts with '@'" do
      it "returns matching file paths with @ prefix" do
        expect(described_class.complete(input: "@foo", agent: agent)).to contain_exactly("@foo.rb")
      end

      it "appends / to directories" do
        expect(described_class.complete(input: "@baz", agent: agent)).to contain_exactly("@baz/")
      end

      it "returns all matches for bare '@'" do
        result = described_class.complete(input: "@", agent: agent)
        expect(result).to include("@foo.rb", "@bar.rb", "@baz/")
      end
    end
  end
end
