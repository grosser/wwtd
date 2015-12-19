require "bundler/gem_tasks"
require "bump/tasks"
require "./lib/wwtd/ruby"
require "./spec/ruby_versions"

task default: ["spec:check"] do
  sh "rspec spec/"
end

namespace :spec do
  task :check do
    missing = RubyVersions::ALL.reject { |ruby| WWTD::Ruby.available?(ruby) }
    fail "ruby #{missing.inspect} required to run tests correctly" if missing.any?
  end
end
