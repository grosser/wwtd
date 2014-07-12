require "bundler/setup"
require "wwtd"
require "tmpdir"
require "benchmark"

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
  config.mock_with(:rspec) { |c| c.syntax = :should }
end
