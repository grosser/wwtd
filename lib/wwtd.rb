require "wwtd/version"
require "optparse"
require "yaml"
require "shellwords"
require "parallel"

module WWTD
  CONFIG = ".travis.yml"
  DEFAULT_GEMFILE = "Gemfile"
  COMBINATORS = ["rvm", "gemfile", "env"]
  UNDERSTOOD = ["rvm", "gemfile", "matrix", "script", "bundler_args"]

  class << self
    def run(argv)
      options = parse_options(argv)

      # Read actual .travis.yml
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})
      config.delete("source_key") # we don't need that we already have the source
      ignored = config.keys - UNDERSTOOD
      puts "Ignoring: #{ignored.join(", ")}" unless ignored.empty?

      # Execute tests
      matrix = matrix(config)
      results = Parallel.map(matrix.each_with_index, :in_processes => options[:parallel].to_i) do |config, i|
        ENV["TEST_ENV_NUMBER"] = (i == 0 ? "" : (i + 1).to_s) if options[:parallel]

        config_info = config_info(matrix, config)
        puts "#{yellow("START")} #{config_info}"

        result = run_config(config)
        info = "#{result ? green("SUCCESS") : red("FAILURE")} #{config_info}"
        puts info

        [result, info]
      end

      # Summary
      if matrix.size > 1
        puts "\nResults:"
        puts results.map(&:last)
      end

      results.all?(&:first) ? 0 : 1
    end

    private

    def config_info(matrix, config)
      config = config.select { |k,v| matrix.map { |c| c[k] }.uniq.size > 1 }.sort
      "#{config.map { |k,v| "#{k}: #{truncate(v, 30)}" }.join(", ")}"
    end

    def tint(color, string)
      if $stdout.tty?
        "\e[#{color}m#{string}\e[0m"
      else
        string
      end
    end

    def red(string)
      tint(31, string)
    end

    def green(string)
      tint(32, string)
    end

    def yellow(string)
      tint(33, string)
    end

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
      value = value.to_s # accidental numbers like 'rvm: 2.0'
      if value.size > number
        "#{value[0...27]}..."
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
            WWTD: Travis simulator - faster + no more waiting for build emails

            Usage:
                wwtd

            Options:
        BANNER
        opts.on("-p", "--parallel [PROCESSES]", Integer, "Run in parallel") { |c| options[:parallel] = c || Parallel.processor_count }
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts WWTD::VERSION; exit}
      end.parse!(argv)
      options
    end
  end
end
