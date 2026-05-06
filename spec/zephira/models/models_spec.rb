require "spec_helper"

RSpec.describe Zephira::Models do
  describe ".available" do
    it "returns all model classes excluding BaseModel" do
      expect(described_class.available).not_to include(Zephira::Models::BaseModel)
      expect(described_class.available).to all(respond_to(:model_name))
    end

    it "includes the expected models" do
      names = described_class.available.map(&:model_name)
      expect(names).to include(
        "claude-3-5-sonnet-20241022",
        "gpt-4.1-mini-2025-04-14",
        "o4-mini-2025-04-16",
        "meta-llama/llama-4-maverick-17b-128e-instruct"
      )
    end
  end

  describe ".find_by_name" do
    it "finds a model by exact name" do
      expect(described_class.find_by_name("o4-mini-2025-04-16")).to eq(Zephira::Models::GptO4Mini)
    end

    it "finds a model case-insensitively" do
      expect(described_class.find_by_name("O4-MINI-2025-04-16")).to eq(Zephira::Models::GptO4Mini)
    end

    it "returns nil for an unknown model name" do
      expect(described_class.find_by_name("not-a-model")).to be_nil
    end
  end

  describe "model definitions" do
    {
      Zephira::Models::Claude35Sonnet => {name: "claude-3-5-sonnet-20241022", context_limit: 200_000},
      Zephira::Models::ChatGpt41Mini => {name: "gpt-4.1-mini-2025-04-14", context_limit: 1_047_576},
      Zephira::Models::GptO4Mini => {name: "o4-mini-2025-04-16", context_limit: 200_000},
      Zephira::Models::Llama4 => {name: "meta-llama/llama-4-maverick-17b-128e-instruct", context_limit: 131_072}
    }.each do |model, attrs|
      context model.name do
        it "has the correct model_name" do
          expect(model.model_name).to eq(attrs[:name])
        end

        it "has the correct context_limit" do
          expect(model.context_limit).to eq(attrs[:context_limit])
        end
      end
    end
  end
end
