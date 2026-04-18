# frozen_string_literal: true

RSpec.configure do |config|
  config.include Module.new {
    def capture_stdout
      old_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  }
end
