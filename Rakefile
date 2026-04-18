# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

# use Standard Ruby style guide for linting
require "standard/rake"

task lint: :standard
task default: %i[spec lint]
