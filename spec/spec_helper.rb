require "bundler/setup"
require "wwtd"
require "tmpdir"
require "benchmark"
require "ruby_versions"

# having global BUNDLE_PATH=vendor/bundle breaks a few tests, but should still work fine on CO
SHARED_GEMS_DISABLED = if ENV['CI']
  false
else
  File.exist?(".bundle/config") && File.read(".bundle/config").include?("BUNDLE_DISABLE_SHARED_GEMS: '1'")
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.mock_with(:rspec) { |c| c.syntax = :should }
end
