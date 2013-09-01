require "wwtd/version"
require "optparse"
require "yaml"
require "shellwords"

module WWTD
  CONFIG = ".travis.yml"
  DEFAULT_GEMFILE = "Gemfile"
  COMBINATORS = ["rvm", "gemfile", "env"]
  UNDERSTOOD = ["rvm", "gemfile", "matrix", "script", "bundler_args"]

  class << self
    def run(argv)
      parse_options(argv)
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})
      ignored = config.keys - UNDERSTOOD
      puts "Ignoring: #{ignored.join(", ")}" unless ignored.empty?

      success = matrix(config).map do |config|
        puts "Start: #{config.to_a.sort.map { |k,v| "#{k}: #{truncate(v, 30)}" }.join(", ")}" unless config.empty?
        result = run_config(config)
        puts "#{result ? "SUCCESS" : "FAILURE"} #{config.to_a.sort.map { |k,v| "#{k}: #{truncate(v, 30)}" }.join(", ")}" unless config.empty?
        result
      end
      success.all? ? 0 : 1
    end

    private

    def matrix(config)
      components = COMBINATORS.map do |multiplier|
        next unless values = config[multiplier]
        Array(values).map { |v| {multiplier => v} }
      end.compact

      components = components.inject([{}]) { |all, v| all.product(v).map! { |values| merge_hashes(values) } }
      if config["matrix"] && config["matrix"]["exclude"]
        components -= config.delete("matrix").delete("exclude")
      end
      components.map! { |c| config.merge(c) }
    end

    def truncate(value, number)
      if value.size > number
        "#{value[0..27]}..."
      else
        value
      end
    end

    def clone(object)
      Marshal.load(Marshal.dump(object))
    end

    def merge_hashes(array)
      array.inject({}) { |all, v| all.merge!(v); all }
    end

    def run_config(config)
      if gemfile = config["gemfile"]
        ENV["BUNDLE_GEMFILE"] = gemfile
      end
      wants_bundle = gemfile || File.exist?(DEFAULT_GEMFILE)

      Shellwords.split(config["env"] || "").each do |part|
        name, value = part.split("=", 2)
        ENV[name] = value
      end

      with_clean_env do
        rvm = "rvm #{config["rvm"]} do " if config["rvm"]

        if wants_bundle
          default_bundler_args = (File.exist?("#{gemfile || DEFAULT_GEMFILE}.lock") ? "--deployment" : "")
          bundle_command = "#{rvm}bundle install #{config["bundler_args"] || default_bundler_args}"
          return false unless sh "#{bundle_command.strip} --quiet"
        end

        default_command = (wants_bundle ? "bundle exec rake" : "rake")
        command = config["script"] || default_command
        command = "#{rvm}#{command}"

        sh(command)
      end
    end

    # http://grosser.it/2010/12/11/sh-without-rake/
    def sh(cmd)
      puts cmd
      IO.popen(cmd) do |pipe|
        while str = pipe.gets
          puts str
        end
      end
      $?.success?
    end

    def with_clean_env(&block)
      if defined?(Bundler)
        Bundler.with_clean_env(&block)
      else
        yield
      end
    end

    def parse_options(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^ {10}/, "")
            Travis simulator so you do not need to wait for the build.

            Usage:
                wwtd

            Options:
        BANNER
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts WWTD::VERSION; exit}
      end.parse!(argv)
      options
    end
  end
end
