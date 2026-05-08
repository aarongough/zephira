# frozen_string_literal: true

require "spec_helper"

RSpec.describe "run_loop", :integration do
  include FakeFS::SpecHelpers

  before do
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_MODEL").and_return("gpt-4.1-mini")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_API_KEY").and_return("test-key")
    allow(Zephira::Config).to receive(:read).with("ZEPHIRA_BASE_URL").and_return(nil)

    allow(Readline).to receive(:completion_proc=)
    allow(Readline).to receive(:readline).and_return(nil)

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

  it "exits cleanly on EOF (readline returns nil)" do
    expect { agent.run_loop }.not_to raise_error
  end

  it "displays the logo on startup" do
    expect { agent.run_loop }.to output(/░▒▓/).to_stdout
  end

  it "displays the greeting on startup" do
    expect { agent.run_loop }.to output(/Hello! I am Zephira/).to_stdout
  end

  it "shows the context percentage in the prompt bar" do
    expect { agent.run_loop }.to output(/context left/).to_stdout
  end

  it "skips blank input without calling inference" do
    allow(Readline).to receive(:readline).and_return("   ", nil)
    allow(agent.model).to receive(:inference)
    agent.run_loop
    expect(agent.model).not_to have_received(:inference)
  end

  it "dispatches a slash command without calling inference" do
    allow(Readline).to receive(:readline).and_return("/help", nil)
    allow(agent.commands).to receive(:run)
    allow(agent.model).to receive(:inference)
    agent.run_loop
    expect(agent.commands).to have_received(:run).with(name: "help", args: [], agent: agent)
    expect(agent.model).not_to have_received(:inference)
  end

  it "prints the assistant response after a plain-text turn" do
    stub_chat(chat_text("Hi there!"))
    allow(Readline).to receive(:readline).and_return("hello", nil)
    expect { agent.run_loop }.to output(/Hi there!/).to_stdout
  end

  it "prints the response after a turn that includes a tool call" do
    stub_chat(
      chat_tool_call(name: "shell", args: {command: "echo hi", intent: "echo hi"}),
      chat_text("All done.")
    )
    allow(Readline).to receive(:readline).and_return("do something", nil)
    expect { agent.run_loop }.to output(/All done\./).to_stdout
  end

  it "echoes the user input before the response" do
    stub_chat(chat_text("Got it."))
    allow(Readline).to receive(:readline).and_return("my question", nil)
    expect { agent.run_loop }.to output(/User:.*my question/m).to_stdout
  end

  it "catches a backend error and continues without crashing" do
    stub_request(:post, ChatStubHelpers::OPENAI_CHAT_URL).to_raise(Faraday::Error.new("connection failed"))
    allow(Readline).to receive(:readline).and_return("hello", nil)
    expect { agent.run_loop }.not_to raise_error
  end

  it "prints an error message when the backend fails" do
    stub_request(:post, ChatStubHelpers::OPENAI_CHAT_URL).to_raise(RuntimeError.new("boom"))
    allow(Readline).to receive(:readline).and_return("hello", nil)
    expect { agent.run_loop }.to output(/Error: boom/).to_stdout
  end
end
