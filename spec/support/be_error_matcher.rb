# frozen_string_literal: true

RSpec::Matchers.define :be_error do |expected_message|
  match do |actual|
    return false unless actual.is_a?(Hash)
    return false unless actual[:outcome] == "error"
    return false unless actual[:data].nil?
    return false if actual[:error].nil?
    expected_message.is_a?(Regexp) ? expected_message.match?(actual[:error]) : actual[:error] == expected_message
  end

  failure_message do |actual|
    return "expected a Hash, got #{actual.class}" unless actual.is_a?(Hash)
    return "expected outcome 'error', got #{actual[:outcome].inspect}" if actual[:outcome] != "error"
    return "expected data to be nil, got #{actual[:data].inspect}" if !actual[:data].nil?
    return "expected error to be #{expected_message.inspect}, but error was nil" if actual[:error].nil?
    "expected error #{expected_message.inspect}, got #{actual[:error].inspect}"
  end

  failure_message_when_negated do |actual|
    "expected result not to be error with #{expected_message.inspect}, got #{actual.inspect}"
  end
end
