require "bundler/setup"
require "wwtd"
require "tmpdir"
require "benchmark"
require "ruby_versions"

# having global BUNDLE_PATH=vendor/bundle breaks a few tests
# somehow it's not set in travis but it still always generates vendor/bundle
BUNDLE_PATH_USED = !ENV["CI"] && [".bundle/config", File.expand_path("~/.bundle/config")].any? do |file|
  File.exist?(file) && File.read(file).include?("BUNDLE_PATH")
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.mock_with(:rspec) { |c| c.syntax = :should }
end
