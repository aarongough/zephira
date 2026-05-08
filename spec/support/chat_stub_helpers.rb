# frozen_string_literal: true

module ChatStubHelpers
  OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

  def stub_chat(*responses)
    stub = stub_request(:post, OPENAI_CHAT_URL)
    responses.each { |body| stub = stub.to_return(status: 200, body: body.to_json, headers: {"Content-Type" => "application/json"}) }
    stub
  end

  def chat_text(content)
    {choices: [{message: {role: "assistant", content: content}}]}
  end

  def chat_tool_call(name:, args:, id: "call_1")
    tool_calls = [{id: id, type: "function", function: {name: name, arguments: args.to_json}}]
    {choices: [{message: {role: "assistant", content: nil, tool_calls: tool_calls}}]}
  end
end

RSpec.configure { |c| c.include ChatStubHelpers, :integration }
