require 'yaml'

module RubyVersions
  ALL = YAML.load_file('.travis.yml').fetch('before_install').map { |l| l.sub!('rvm install ', '') }.compact

  raise "before_install rubies are wrong (#{ALL.join(", ")})" unless
    ALL.size == 3 &&
    ALL[0] =~ /^\d+\.\d+\.\d+$/ &&
    ALL[1] =~ /^\d+\.\d+\.\d+$/ &&
    ALL[2] =~ /^jruby-\d+\.\d+\.\d+(\.\d+)?$/

  RUBY_1 = ALL[0]
  RUBY_2 = ALL[1]
  JRUBY = ALL[2]
end
