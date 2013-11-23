module WWTD
  class Run
    def initialize(config, env, lock)
      @config, @env, @lock = config, env, lock
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

    private

    attr_reader :config, :env, :lock

    def success?
      # TODO extract into method
      Shellwords.split(config["env"] || "").each do |part|
        name, value = part.split("=", 2)
        env[name] = value
      end

      if gemfile = config["gemfile"]
        env["BUNDLE_GEMFILE"] = gemfile
      end

      # END
      wants_bundle = gemfile || File.exist?(DEFAULT_GEMFILE)

      switch_ruby = Ruby.switch_statement(config["rvm"])
      if switch_ruby.is_a?(Hash)
        env.merge!(switch_ruby)
        switch_ruby = nil
      end

      if wants_bundle
        flock("#{lock}/#{config["rvm"] || "rvm"}") do
          default_bundler_args = "--deployment --path #{Dir.pwd}/vendor/bundle" if committed?("#{gemfile || DEFAULT_GEMFILE}.lock")
          bundle_command = "#{switch_ruby}bundle install #{config["bundler_args"] || default_bundler_args}"
          return false unless sh(env, "#{bundle_command.strip} --quiet")
        end
      end

      default_command = (wants_bundle ? "bundle exec rake" : "rake")
      command = config["script"] || default_command
      command = "#{switch_ruby}#{command}"

      sh(env, command)
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
    # http://grosser.it/2010/12/11/sh-without-rake/
    def sh(env, cmd=nil)
      cmd, env = env, {} unless cmd
      puts cmd
      IO.popen(env, cmd) do |pipe|
        while str = pipe.gets
          puts str
        end
      end
      $?.success?
    end
  end
end
