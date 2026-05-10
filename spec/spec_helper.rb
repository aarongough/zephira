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
require "webmock/rspec"
require "zephira"
# Requiring PP before FakeFS Fixes the known `superclass mismatch` issue with FakeFS:
# https://github.com/fakefs/fakefs#fakefs-----typeerror-superclass-mismatch-for-class-file
require "pp"
require "fakefs/spec_helpers"

# Load custom matchers from spec/support
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do |example|
    next if example.metadata[:show_output]

    @_real_stdout = $stdout
    @_real_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  config.after(:each) do
    $stdout = @_real_stdout if @_real_stdout
    $stderr = @_real_stderr if @_real_stderr
  end

  # Default Config.read to return nil so per-test stubs can override only the
  # specific keys they care about without tripping strict-arg verification on
  # other reads (e.g. ZEPHIRA_DEBUG). Opt out with `:real_config` for tests
  # that exercise Config itself.
  config.before(:each) do |example|
    next if example.metadata[:real_config]
    allow(Zephira::Config).to receive(:read).and_return(nil)
  end
end
