require "wwtd"

run_wwtd = lambda { |args| exit 1 unless WWTD::CLI.run(args) == 0 }
task :wwtd do
  run_wwtd.call([])
end

namespace :wwtd do
  task :parallel do
    run_wwtd.call(["--parallel"])
  end
end
