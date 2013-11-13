require "wwtd/version"
require "optparse"
require "yaml"
require "shellwords"
require "parallel"
require "tempfile"
require "tmpdir"

module WWTD
  CONFIG = ".travis.yml"
  DEFAULT_GEMFILE = "Gemfile"
  COMBINATORS = ["rvm", "gemfile", "env"]
  UNDERSTOOD = ["rvm", "gemfile", "matrix", "script", "bundler_args"]
  INFO_MAX_CHARACTERS = 30

  class << self
    def run(argv=[])
      options = parse_options(argv)

      # Read actual .travis.yml
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})
      config.delete("source_key") # we don't need that we already have the source
      ignored = config.keys - UNDERSTOOD
      puts "Ignoring: #{ignored.sort.join(", ")}" unless ignored.empty?

      # Execute tests
      matrix = matrix(config)
      results = run_full_matrix(matrix, options)

      # Summary
      if matrix.size > 1
        puts "\nResults:"
        puts results.map(&:last)
      end

      results.all?(&:first) ? 0 : 1
    end

    private

    def run_full_matrix(matrix, options)
      results = nil
      with_clean_dot_bundle do
        Dir.mktmpdir do |lock| # does not return values in ruby 1.8
          results = Parallel.map(matrix.each_with_index, :in_processes => options[:parallel].to_i) do |config, i|
            ENV["TEST_ENV_NUMBER"] = (i == 0 ? "" : (i + 1).to_s) if options[:parallel]

            config_info = config_info(matrix, config)
            puts "#{yellow("START")} #{config_info}"

            result = run_config(config, lock)
            info = "#{result ? green("SUCCESS") : red("FAILURE")} #{config_info}"
            puts info

            [result, info]
          end
        end
      end
      results
    end

    def with_clean_dot_bundle
      had_old = File.exist?(".bundle")
      Dir.mktmpdir do |dir|
        begin
          sh "mv .bundle #{dir}" if had_old
          yield
        ensure
          sh "rm -rf .bundle"
          sh "mv #{dir}/.bundle ." if had_old
        end
      end
    end

    def config_info(matrix, config)
      config = config.select { |k,v| matrix.map { |c| c[k] }.uniq.size > 1 }.sort # find non-unique values aka interesting
      maximum_value_lengths = Hash[config.map { |k,v| [k, matrix.map { |h| h[k].to_s.size }.max ] }] # find maximum value length for each key so we can align
      config.map do |k, v|
        value = truncate(v, INFO_MAX_CHARACTERS).ljust([INFO_MAX_CHARACTERS, maximum_value_lengths[k]].min)
        "#{k}: #{value}"
      end.join(" ") # truncate values that are too long
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
      matrix = [{}]
      COMBINATORS.each do |multiplier|
        next unless values = config[multiplier]
        matrix = Array(values).map { |value| matrix.map { |c| c.merge(multiplier => value) } }.flatten
      end

      if config["matrix"] && config["matrix"]["exclude"]
        matrix -= config.delete("matrix").delete("exclude")
      end
      matrix.map! { |c| config.merge(c) }
    end

    def truncate(value, number)
      value = value.to_s # accidental numbers like 'rvm: 2.0'
      if value.size > number
        "#{value[0...27]}..."
      else
        value
      end
    end

    def run_config(config, lock)
      with_clean_env do
        Shellwords.split(config["env"] || "").each do |part|
          name, value = part.split("=", 2)
          ENV[name] = value
        end

        if gemfile = config["gemfile"]
          ENV["BUNDLE_GEMFILE"] = gemfile
        end
        wants_bundle = gemfile || File.exist?(DEFAULT_GEMFILE)

        switch_ruby = switch_ruby(config["rvm"])

        if wants_bundle
          flock("#{lock}/#{config["rvm"] || "rvm"}") do
            default_bundler_args = "--deployment --path #{Dir.pwd}/vendor/bundle" if committed?("#{gemfile || DEFAULT_GEMFILE}.lock")
            bundle_command = "#{switch_ruby}bundle install #{config["bundler_args"] || default_bundler_args}"
            return false unless sh "#{bundle_command.strip} --quiet"
          end
        end

        default_command = (wants_bundle ? "bundle exec rake" : "rake")
        command = config["script"] || default_command
        command = "#{switch_ruby}#{command}"

        sh(command)
      end
    end

    def switch_ruby(version)
      return unless version
      version = normalize_ruby_version(version)
      if rvm_executable
        "rvm #{version} do "
      else
        if ruby_root = ENV["RUBY_ROOT"] # chruby or RUBY_ROOT set
          switch_path(File.dirname(ruby_root), version)
        elsif rbenv_executable
          rubies_root = cache_command("which rbenv").sub(%r{/(\.?rbenv)/.*}, "/\\1") + "/versions"
          switch_path(rubies_root, version)
        else
          "false # could not find rvm, rbenv or RUBY_ROOT # "
        end
      end
    end

    def switch_path(rubies_root, version)
      extract_jruby_rbenv_options!(version)
      if ruby_root = ruby_root(rubies_root, version)
        gem_home = Dir["#{ruby_root}/lib/ruby/gems/*"].first
        ENV["PATH"] = "#{ruby_root}/bin:#{ENV["PATH"]}"
        ENV["GEM_HOME"] = gem_home
        ""
      else
        "false # could not find #{version} in #{rubies_root} # "
      end
    end

    def rvm_executable
      cache_command("which rvm")
    end

    def rbenv_executable
      cache_command("which rbenv")
    end

    def cache_command(command)
      cache(command) do
        if result = capture(command)
          result.strip
        end
      end
    end

    def ruby_root(root, version)
      Dir.glob("#{root}/*").detect { |p| File.basename(p).start_with?(version) }
    end

    def cache(key)
      @cache ||= {}
      if @cache.key?(key)
        @cache[key]
      else
        @cache[key] = yield
      end
    end

    # set ruby-opts for jruby flavors
    def extract_jruby_rbenv_options!(version)
      if version.sub!("-d19", "")
        ENV["JRUBY_OPTS"] = "--1.9"
      elsif version.sub!("-d18", "")
        ENV["JRUBY_OPTS"] = "--1.8"
      end
    end

    def capture(command)
      result = `#{command}`
      $?.success? ? result : nil
    end

    # Taken from https://github.com/travis-ci/travis-build/blob/master/lib/travis/build/script/rvm.rb
    def normalize_ruby_version(rvm)
      rvm.to_s.
        gsub(/-(\d{2})mode$/, '-d\1').
        gsub(/^rbx$/, 'rbx-weekly-d18').
        gsub(/^rbx-d(\d{2})$/, 'rbx-weekly-d\1')
    end

    def committed?(file)
      @committed_files ||= (File.exist?(".git") && `git ls-files`.split("\n")) || []
      @committed_files.include?(file)
    end

    def flock(file)
      File.open(file, "w") do |f|
        begin
          f.flock(File::LOCK_EX)
          yield
        ensure
          f.flock(File::LOCK_UN)
        end
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
