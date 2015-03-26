name = "wwtd"
require "./lib/#{name}/version"

Gem::Specification.new name, WWTD::VERSION do |s|
  s.summary = "Travis simulator so you do not need to wait for the build"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/`.split("\n")
  s.license = "MIT"
  s.executables = ["wwtd"]
end
