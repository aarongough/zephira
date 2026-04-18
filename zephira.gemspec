# frozen_string_literal: true

require_relative "lib/zephira/version"

Gem::Specification.new do |spec|
  spec.name = "zephira"
  spec.version = Zephira::VERSION
  spec.authors = ["Aaron Gough"]
  spec.email = ["aaron@aarongough.com"]

  spec.summary = "Command-line AI coding assistant in Ruby."
  spec.description = "Zephira is a CLI AI coding assistant implemented in Ruby with plugin-style tools and a pipeline-driven architecture."
  spec.homepage = "https://github.com/aarongough/zephira"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = spec.homepage + "/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies

  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.13.2"
  spec.add_development_dependency "standard", "~> 1.54"
end
