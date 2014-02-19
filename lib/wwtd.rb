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
  UNDERSTOOD = ["rvm", "gemfile", "matrix", "script", "bundler_args"]

  class << self
    def read_travis_yml
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})
      config.delete("source_key") # we don't need that we already have the source
      ignored = config.keys - UNDERSTOOD
      [matrix(config), ignored]
    end

    def run(matrix, options, &block)
      with_clean_dot_bundle do
        with_clean_env do
          Dir.mktmpdir do |lock|
            in_multiple_threads(matrix.each_with_index, options[:parallel]) do |config, i|
              # set env as parallel_tests does to reuse existing infrastructure
              env = {}
              env["TEST_ENV_NUMBER"] = (i == 0 ? "" : (i + 1).to_s) if options[:parallel]
              Run.new(config, env, lock).execute(&block)
            end
          end
        end
      end
    end

    private

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
        config["env"] = config["env"].values.map { |v| v.join(" ")}
      end

      matrix = [{}]
      COMBINATORS.each do |multiplier|
        next unless values = config[multiplier]
        matrix = Array(values).map { |value| matrix.map { |c| c.merge(multiplier => value) } }.flatten
      end

      matrix_config = config.delete("matrix")
      if matrix_config && matrix_config["exclude"]
        matrix -= matrix_config["exclude"]
      end
      if matrix_config && matrix_config["include"]
        matrix += matrix_config["include"]
      end
      matrix.map! { |c| config.merge(c) }
    end

    def sh(env, cmd=nil)
      cmd, env = env, {} unless cmd
      env = if env.any?
        env.map {|k,v| "export #{k}=#{Shellwords.escape(v)}" }.join(" && ") + " && "
      else
        ""
      end
      puts cmd
      system("#{env}#{cmd}")
    end

    def with_clean_env(&block)
      if defined?(Bundler)
        Bundler.with_clean_env(&block)
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
