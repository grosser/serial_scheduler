# frozen_string_literal: true
name = "serial_scheduler"
$LOAD_PATH << File.expand_path("lib", __dir__)
require "#{name.tr("-", "/")}/version"

Gem::Specification.new name, SerialScheduler::VERSION do |s|
  s.summary = "Simple scheduler for long-running and infrequent tasks, no threads, always in serial"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "https://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/ MIT-LICENSE`.split("\n")
  s.license = "MIT"
  s.required_ruby_version = ">= 2.5.0" # keep in sync with .rubocop.yml
  s.add_development_dependency "fugit"
end
