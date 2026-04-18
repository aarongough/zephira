# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch

  add_filter "/spec/"
  add_filter "/exe/"
end

begin
  require "bundler/setup"
rescue LoadError => e
  abort("Bundler setup failed (#{e.message}); please run specs via `bundle exec rspec`.")
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rspec"
require "zephira"

# Load custom matchers from spec/support
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |f| require f }

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
