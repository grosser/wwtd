require "wwtd/version"
require "optparse"
require "yaml"
require "shellwords"
require "tempfile"
require "tmpdir"
require "wwtd/ruby"
require "wwtd/run"
require "wwtd/cli"

module WWTD
  CONFIG = ".travis.yml"
  DEFAULT_GEMFILE = "Gemfile"
  COMBINATORS = ["rvm", "gemfile", "env"]
  UNDERSTOOD = COMBINATORS + ["matrix", "script", "bundler_args"]

  class << self
    def read_travis_yml(options={})
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})
      config.delete("source_key") # we don't need that we already have the source
      ignored = (config.keys - UNDERSTOOD - Array(options[:use])) + Array(options[:ignore])

      calculate_local_ruby_matrix = (
        ignored.include?("rvm") &&
        Array(config["rvm"]).include?(RUBY_VERSION) &&
        config["matrix"]
      )

      ignored.each { |i| config.delete(i) unless i == "rvm" && calculate_local_ruby_matrix }
      matrix = matrix(config)

      if calculate_local_ruby_matrix
        matrix.delete_if { |m| m["rvm"] != RUBY_VERSION }
        matrix.each { |m| m.delete("rvm") }
      end

      [matrix, ignored]
    end

    def run(matrix, options, &block)
      with_clean_dot_bundle do
        with_clean_env do
          Dir.mktmpdir do |lock|
            in_multiple_threads(matrix.each_with_index, options[:parallel]) do |config, i|
              # set env as parallel_tests does to reuse existing infrastructure
              env = {}
              env["TEST_ENV_NUMBER"] = (i == 0 ? "" : (i + 1).to_s) if options[:parallel]
              if options[:only_bundle]
                config['script'] = 'test "only bundle"'
              end
              Run.new(config, env, lock).execute(&block)
            end
          end
        end
      end
    end

    # internal api
    # needs the export to work on ruby 1.9 / linux
    def escaped_env(env, options={})
      return "" if env.empty?

      if options[:rerun] && gemfile = env["BUNDLE_GEMFILE"]
        env["BUNDLE_GEMFILE"] = gemfile.sub("#{Dir.pwd}/", "")
      end

      env = env.map { |k,v| "#{k}=#{Shellwords.escape(v)}" }
      if options[:rerun]
        env.join(" ") + " "
      else
        env.map { |e| "export #{e}" }.join(" && ") + " && "
      end
    end

    private

    # internal api
    def sh(env, cmd=nil)
      cmd, env = env, {} unless cmd
      env = escaped_env(env)
      puts cmd
      system("#{env}#{cmd}")
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
      if config["env"] && config["env"].is_a?(Hash)
        global = if config["env"]["global"]
          " " + config["env"]["global"].join(" ")
        else
          ""
        end
        if config["env"]["matrix"]
          config["env"] = config["env"]["matrix"].map { |v| v + global }
        else
          config["env"] = global.strip
        end
      end

      matrix = [{}]
      COMBINATORS.each do |multiplier|
        next unless values = config[multiplier]
        matrix = Array(values).map { |value| matrix.map { |c| c.merge(multiplier => value) } }.flatten
      end

      if matrix_config = config.delete("matrix")
        if exclude = matrix_config["exclude"]
          exclude.each do |exclude_cell|
            matrix.delete_if { |cell| matrix_match?(cell, exclude_cell) }
          end
        end
        if include = matrix_config["include"]
          if matrix == [{}]
            matrix = include
          else
            matrix += include
          end
        end
      end
      matrix.map! { |c| config.merge(c) }
    end

    def matrix_match?(cell, exclude)
      cell.values_at(*exclude.keys) == exclude.values
    end

    def with_clean_env(&block)
      if defined?(Bundler)
        method = (Bundler.respond_to?(:with_unbundled_env) ? :with_unbundled_env : :with_clean_env)
        Bundler.send(method, &block)
      else
        yield
      end
    end

    def in_multiple_threads(data, count)
      data = data.to_a.dup
      threads = [count || 1, data.size].min
      results = []
      (0...threads).to_a.map do
        Thread.new do
          while slice = data.shift
            results << yield(slice)
          end
        end
      end.each(&:join)
      results
    end
  end
end
