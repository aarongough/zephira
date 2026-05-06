# frozen_string_literal: true

RSpec::Matchers.define :be_success do |expected_data = :__no_argument__|
  match do |actual|
    return false unless actual.is_a?(Hash)
    return false unless actual[:outcome] == "success"
    return false unless actual[:error].nil?
    expected_data == :__no_argument__ || actual[:data] == expected_data
  end

  failure_message do |actual|
    return "expected a Hash, got #{actual.class}" unless actual.is_a?(Hash)
    return "expected outcome 'success', got #{actual[:outcome].inspect}" if actual[:outcome] != "success"
    return "expected error to be nil, got #{actual[:error].inspect}" if !actual[:error].nil?
    "expected data #{expected_data.inspect}, got #{actual[:data].inspect}"
  end

  failure_message_when_negated do |actual|
    "expected result not to be success, got #{actual.inspect}"
  end
end
