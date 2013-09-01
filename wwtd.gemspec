$LOAD_PATH.unshift File.expand_path("../lib", __FILE__)
name = "wwtd"
require "#{name.gsub("-","/")}/version"

Gem::Specification.new name, WWTD::VERSION do |s|
  s.summary = "Travis simulator so you do not need to wait for the build"
  s.authors = ["Michael Grosser"]
  s.email = "michael@grosser.it"
  s.homepage = "http://github.com/grosser/#{name}"
  s.files = `git ls-files lib/ bin/`.split("\n")
  s.license = "MIT"
  s.executables = ["wwtd"]
  s.add_runtime_dependency "parallel"
  cert = File.expand_path("~/.ssh/gem-private-key-grosser.pem")
  if File.exist?(cert)
    s.signing_key = cert
    s.cert_chain = ["gem-public_cert.pem"]
  end
end
