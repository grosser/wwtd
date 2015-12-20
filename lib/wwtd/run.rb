module WWTD
  class Run

    SECTIONS = ["before_install", "install", "before_script", "script", "after_script"]

    def initialize(config, env, lock)
      @config, @env, @lock = config, env, lock
      add_env_from_config
      @switch = build_switch_statement
    end

    def execute
      state = if Ruby.available?(config["rvm"])
        yield(:start, config)
        success? ? :success : :failure
      else
        :missing_ruby_version
      end

      yield(state, config)

      [state, config]
    end

    # internal api
    def env_and_command_for_section(key)
      if command = config[key]
        command = [command] unless Array === command
        command = command.map { |cmd| "#{switch}#{cmd}" }.join(" && ")

        [env, command]
      elsif key == "script"
        command = (wants_bundle? ? "#{switch}bundle exec rake" : "#{switch}rake")
        [env, command]
      end
    end

    private

    attr_reader :config, :env, :lock, :switch

    def success?
      if wants_bundle?
        flock File.join(lock, (config["rvm"] || "rvm").to_s) do
          default_bundler_args = "--deployment --path #{Dir.pwd}/vendor/bundle" if committed?("#{gemfile || DEFAULT_GEMFILE}.lock")
          bundle_command = "#{switch}bundle install #{config["bundler_args"] || default_bundler_args}"
          return false unless sh(env, "#{bundle_command.strip} --quiet")
        end
      end

      SECTIONS.each do |section|
        if env_and_command = env_and_command_for_section(section)
          return unless sh(*env_and_command)
        end
      end
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
      env["BUNDLE_GEMFILE"] = File.expand_path(gemfile) if gemfile
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
