module WWTD
  class Run
    def initialize(config, env, lock)
      @config, @env, @lock = config, env, lock
      add_env_from_config
      @switch = build_switch_statement
    end

    def execute(&block)
      state = if Ruby.available?(config["rvm"])
        yield(:start, config)
        success? ? :success : :failure
      else
        :missing
      end

      yield(state, config)

      [state, config]
    end

    # internal api
    def env_and_command
      default_command = (wants_bundle? ? "bundle exec rake" : "rake")
      command = config["script"] || default_command
      command = command.join(" && ") if Array === command
      command = "#{switch}#{command}"

      [env, command]
    end

    private

    attr_reader :config, :env, :lock, :switch


    def success?
      if wants_bundle?
        flock File.join(lock, (config["rvm"] || "rvm").to_s) do
          default_bundler_args = "--deployment --path #{Dir.pwd}/vendor/bundle" if committed?("#{gemfile || DEFAULT_GEMFILE}.lock")
          bundle_command = "#{switch}bundle install #{config["bundler_args"] || default_bundler_args}"
          env = env().merge("BUNDLE_IGNORE_CONFIG" => "1")
          return false unless sh(env, "#{bundle_command.strip} --quiet")
        end
      end

      sh(*env_and_command)
    end

    def wants_bundle?
      gemfile || File.exist?(DEFAULT_GEMFILE)
    end

    def gemfile
      config["gemfile"]
    end

    def build_switch_statement
      switch_ruby = Ruby.switch_statement(config["rvm"], :rerun => config[:rerun])
      if switch_ruby.is_a?(Hash)
        env.merge!(switch_ruby)
        switch_ruby = nil
      end
      switch_ruby
    end

    def add_env_from_config
      Shellwords.split(config["env"] || "").each do |part|
        name, value = part.split("=", 2)
        env[name] = value
      end
      env["BUNDLE_GEMFILE"] = gemfile if gemfile
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

    def sh(*args)
      ::WWTD.send(:sh, *args)
    end
  end
end
