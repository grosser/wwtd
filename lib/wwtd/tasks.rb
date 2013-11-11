require "wwtd"

task :wwtd do
  block = lambda{ sh "wwtd" }
  if defined?(Bundler)
    Bundler.with_clean_env(&block)
  else
    block.call
  end
end
