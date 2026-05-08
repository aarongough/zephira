# frozen_string_literal: true

require "spec_helper"

RSpec.describe "backend HTTP errors", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)

    allow(Readline).to receive(:completion_proc=)
    allow(Readline).to receive(:readline).and_return("hello", nil)

    allow(TTY::Screen).to receive(:width).and_return(80)
    allow(TTY::Screen).to receive(:height).and_return(24)
    allow(TTY::Screen).to receive(:rows).and_return(24)
    allow(TTY::Cursor).to receive(:hide)
    allow(TTY::Cursor).to receive(:show)
    allow(TTY::Cursor).to receive(:up).and_return("")
    allow(TTY::Spinner).to receive(:new).and_return(spinner_double)
  end

  let(:agent) { Zephira::Agent.new }

  let(:spinner_double) do
    instance_double(TTY::Spinner).tap do |s|
      allow(s).to receive(:on)
      allow(s).to receive(:spin)
      allow(s).to receive(:run) { |_, &block| block&.call }
    end
  end

  def stub_api_response(status, body = {error: {message: "API error"}})
    stub_request(:post, ChatStubHelpers::OPENAI_CHAT_URL)
      .to_return(status: status, body: body.to_json, headers: {"Content-Type" => "application/json"})
  end

  it "handles a 401 unauthorized response without crashing" do
    stub_api_response(401)
    expect { agent.run_loop }.not_to raise_error
  end

  it "prints an error message on 401" do
    stub_api_response(401)
    expect { agent.run_loop }.to output(/Error/).to_stdout
  end

  it "handles a 429 rate-limit response without crashing" do
    stub_api_response(429)
    expect { agent.run_loop }.not_to raise_error
  end

  it "handles a 500 server error without crashing" do
    stub_api_response(500)
    expect { agent.run_loop }.not_to raise_error
  end

  it "handles a connection timeout without crashing" do
    stub_request(:post, ChatStubHelpers::OPENAI_CHAT_URL).to_timeout
    expect { agent.run_loop }.not_to raise_error
  end

  it "prints an error message on timeout" do
    stub_request(:post, ChatStubHelpers::OPENAI_CHAT_URL).to_timeout
    expect { agent.run_loop }.to output(/Error/).to_stdout
  end
end
