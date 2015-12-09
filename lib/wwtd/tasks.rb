require "wwtd"

run_wwtd = lambda { |args| exit 1 unless WWTD::CLI.run(args) == 0 }
desc "test on all combinations defined in .travis.yml"
task :wwtd do
  run_wwtd.call([])
end

namespace :wwtd do
  desc "test on all combinations defined in .travis.yml in parallel"
  task :parallel do
    run_wwtd.call(["--parallel"])
  end

  desc "test on all combinations defined in .travis.yml on current ruby"
  task :local do
    run_wwtd.call(["--ignore", "rvm"])
  end

  desc "bundle for all combinations"
  task :bundle do
    run_wwtd.call(["--only-bundle", "--ignore", "rvm"])
  end
end
