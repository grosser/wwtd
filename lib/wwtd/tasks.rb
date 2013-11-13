require "wwtd"

task :wwtd do
  exit 1 unless WWTD.run == 0
end
