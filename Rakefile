require "bundler/gem_tasks"
require "bump/tasks"
require "./lib/wwtd/ruby"
require "./spec/ruby_versions"

task default: ["spec:check"] do
  sh "rspec spec/"
end

namespace :spec do
  task :check do
    all_available = true
    RubyVersions::ALL.each do |v|
      unless WWTD::Ruby.available?(v)
        all_available = false
        p "ruby #{v} required to run tests correctly"
      end
      unless all_available
        fail "Not all requirements available"
      end
    end
  end
end
