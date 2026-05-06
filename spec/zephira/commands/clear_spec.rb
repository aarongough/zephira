# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Commands::Clear do
  let(:history) { double("history", clear: nil, clear_session: nil) }
  let(:agent) { double("agent", history: history) }

  describe ".run" do
    context "with no args" do
      it "prints usage" do
        expect { described_class.run(agent: agent, args: nil) }
          .to output(/Usage/).to_stdout
      end
    end

    context "with 'session'" do
      it "clears session history" do
        described_class.run(agent: agent, args: ["session"])
        expect(history).to have_received(:clear_session)
      end

      it "prints confirmation" do
        expect { described_class.run(agent: agent, args: ["session"]) }
          .to output(/cleared/).to_stdout
      end
    end

    context "with 'all'" do
      it "clears all history" do
        described_class.run(agent: agent, args: ["all"])
        expect(history).to have_received(:clear)
      end

      it "prints confirmation" do
        expect { described_class.run(agent: agent, args: ["all"]) }
          .to output(/cleared/i).to_stdout
      end
    end

    context "with unknown option" do
      it "prints usage" do
        expect { described_class.run(agent: agent, args: ["last"]) }
          .to output(/Usage/).to_stdout
      end
    end
  end
end
