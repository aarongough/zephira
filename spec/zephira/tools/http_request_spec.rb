# frozen_string_literal: true

require "spec_helper"

RSpec.describe Zephira::Tools::HttpRequest do
  let(:logger) { double("logger", info: nil, warn: nil, error: nil) }
  let(:status) { double("status", verbose: nil, warn: nil) }
  let(:agent) { double("agent", logger: logger, status: status, update_status: nil) }

  def run(args)
    described_class.run(args: args.merge("intent" => described_class.name), agent: agent)
  end

  describe ".parameters" do
    it "requires intent, method, and url" do
      expect(described_class.parameters[:required]).to contain_exactly("intent", "method", "url")
    end

    it "restricts method to known HTTP verbs" do
      enum = described_class.parameters[:properties][:method][:enum]
      expect(enum).to contain_exactly("GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS")
    end
  end

  describe ".run" do
    context "GET request" do
      before do
        stub_request(:get, "https://example.com/api")
          .to_return(status: 200, body: '{"ok":true}', headers: {"Content-Type" => "application/json"})
      end

      it "returns success" do
        expect(run("method" => "GET", "url" => "https://example.com/api")).to be_success
      end

      it "returns status, headers, and body" do
        result = run("method" => "GET", "url" => "https://example.com/api")
        expect(result[:data][:status]).to eq(200)
        expect(result[:data][:body]).to eq('{"ok":true}')
        expect(result[:data][:headers]).to include("content-type" => "application/json")
      end

      it "logs and emits verbose status" do
        run("method" => "GET", "url" => "https://example.com/api")
        expect(status).to have_received(:verbose).with(" • GET https://example.com/api")
        expect(status).to have_received(:verbose).with(" • Response: 200")
        expect(logger).to have_received(:info).with("GET https://example.com/api -> 200")
      end
    end

    context "POST request with Hash body" do
      before do
        stub_request(:post, "https://example.com/items")
          .with(body: '{"name":"widget"}', headers: {"Content-Type" => "application/json"})
          .to_return(status: 201, body: "", headers: {})
      end

      it "serializes the body as JSON and sets Content-Type" do
        result = run("method" => "POST", "url" => "https://example.com/items", "body" => {"name" => "widget"})
        expect(result[:data][:status]).to eq(201)
      end
    end

    context "POST request with string body" do
      before do
        stub_request(:post, "https://example.com/raw")
          .with(body: "plain text")
          .to_return(status: 200, body: "", headers: {})
      end

      it "sends the string body as-is" do
        result = run("method" => "POST", "url" => "https://example.com/raw", "body" => "plain text")
        expect(result).to be_success
      end
    end

    context "query parameters" do
      before do
        stub_request(:get, "https://example.com/search")
          .with(query: {"q" => "ruby", "page" => "1"})
          .to_return(status: 200, body: "", headers: {})
      end

      it "appends query params to the URL" do
        result = run("method" => "GET", "url" => "https://example.com/search", "query" => {"q" => "ruby", "page" => "1"})
        expect(result).to be_success
      end
    end

    context "custom headers" do
      before do
        stub_request(:get, "https://example.com/")
          .with(headers: {"X-Token" => "secret"})
          .to_return(status: 200, body: "", headers: {})
      end

      it "sends the headers" do
        result = run("method" => "GET", "url" => "https://example.com/", "headers" => {"X-Token" => "secret"})
        expect(result).to be_success
      end
    end

    context "unsupported method" do
      it "returns an error" do
        result = run("method" => "BREW", "url" => "https://example.com/")
        expect(result).to be_error(/Unsupported HTTP method/)
      end
    end

    context "connection error" do
      before do
        stub_request(:get, "https://unreachable.example.com/")
          .to_raise(SocketError.new("getaddrinfo failed"))
      end

      it "returns an error" do
        result = run("method" => "GET", "url" => "https://unreachable.example.com/")
        expect(result).to be_error(/getaddrinfo/)
      end
    end
  end
end
