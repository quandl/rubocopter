$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "rubocopter/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "rubocopter"
  s.version     = RuboCopter::VERSION
  s.authors     = ["Matthew Basset"]
  s.email       = ["matthew@quandl.com"]
  s.homepage    = "https://github.com/quandl/rubocopter"
  s.summary     = "Propel your RuboCop checking forward."
  s.description = "Helps with speeding up RuboCop checks in large git projects."
  s.license     = "MIT"

  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = '>= 1.9.3'

  s.files = Dir["{bin,lib,git_hooks}/**/*", "MIT-LICENSE", "README.md"]
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = Dir["test/**/*"]
  s.require_paths = ['lib']

  s.add_dependency "rubocop", ">= 0.29.1"
end
