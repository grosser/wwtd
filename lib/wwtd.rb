require "wwtd/version"
require "optparse"
require "yaml"
require "shellwords"
require "parallel"
require "tempfile"
require "tmpdir"
require "wwtd/ruby"
require "wwtd/cli"

module WWTD
  CONFIG = ".travis.yml"
  DEFAULT_GEMFILE = "Gemfile"
  COMBINATORS = ["rvm", "gemfile", "env"]
  UNDERSTOOD = ["rvm", "gemfile", "matrix", "script", "bundler_args"]

  class << self
    def read_travis_yml
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})
      config.delete("source_key") # we don't need that we already have the source
      ignored = config.keys - UNDERSTOOD
      [matrix(config), ignored]
    end

    def run(matrix, options, &block)
      run_in_parallel(matrix, options) do |config, lock|
        state = if Ruby.available?(config["rvm"])
          yield(:start, config, matrix)
          result = run_config(config, lock)
          result ? :success : :failure
        else
          :missing
        end

        yield(state, config)

        [state, config]
      end
    end

    private

    def run_in_parallel(matrix, options)
      results = nil
      with_clean_dot_bundle do
        Dir.mktmpdir do |lock| # does not return values in ruby 1.8
          results = Parallel.map(matrix.each_with_index, :in_processes => options[:parallel].to_i) do |config, i|
            # set env as parallel_tests does to reuse existing infrastructure
            ENV["TEST_ENV_NUMBER"] = (i == 0 ? "" : (i + 1).to_s) if options[:parallel]
            yield config, lock
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

        switch_ruby = Ruby.switch_statement(config["rvm"])

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
  end
end
