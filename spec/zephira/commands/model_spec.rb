# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::Model do
  let(:model_a) { double("ModelA", model_name: "gpt-4.1-mini") }
  let(:model_b) { double("ModelB", model_name: "claude-sonnet-4-5") }
  let(:agent) { double("agent", model: model_a, "model=": nil) }

  before do
    stub_const("Zephira::Models::BaseModel", Class.new)
    stub_const("Zephira::Models::ModelA", model_a)
    stub_const("Zephira::Models::ModelB", model_b)
  end

  describe ".run" do
    context "with no args" do
      it "lists all non-base models" do
        expect { described_class.run(agent: agent, args: []) }
          .to output(/gpt-4.1-mini/).to_stdout
      end

      it "marks the current model" do
        expect { described_class.run(agent: agent, args: []) }
          .to output(/\*.*gpt-4.1-mini.*\(current\)/m).to_stdout
      end
    end

    context "with 'set MODEL_NAME'" do
      it "changes the agent model" do
        described_class.run(agent: agent, args: ["set", "claude-sonnet-4-5"])
        expect(agent).to have_received(:model=).with(model_b)
      end

      it "prints confirmation" do
        expect { described_class.run(agent: agent, args: ["set", "claude-sonnet-4-5"]) }
          .to output(/Model changed to claude-sonnet-4-5/).to_stdout
      end
    end

    context "with 'MODEL_NAME' (without set)" do
      it "also changes the model" do
        described_class.run(agent: agent, args: ["claude-sonnet-4-5"])
        expect(agent).to have_received(:model=).with(model_b)
      end
    end

    context "with unknown model name" do
      it "prints an error" do
        expect { described_class.run(agent: agent, args: ["unknown-model"]) }
          .to output(/Unknown model/).to_stdout
      end
    end

    context "with 'set' and no model name" do
      it "prints usage" do
        expect { described_class.run(agent: agent, args: ["set"]) }
          .to output(/Usage/).to_stdout
      end
    end
  end
end
