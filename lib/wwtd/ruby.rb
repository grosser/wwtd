module WWTD
  module Ruby
    class << self
      def available?(version)
        !version || switch_statement(version)
      end

      # - rvm: "rvm xxx do"
      # - others: env hash
      # - unknown: nil
      def switch_statement(version)
        return unless version
        version = normalize_ruby_version(version)
        if rvm_executable
          command = "rvm #{version} do "
          command if cache_command("#{command} ruby -v")
        else
          if ruby_root = ENV["RUBY_ROOT"] # chruby or RUBY_ROOT set
            switch_via_env(File.dirname(ruby_root), version)
          elsif rbenv_executable
            rubies_root = cache_command("rbenv root") + "/versions"
            switch_via_env(rubies_root, version)
          end
        end
      end

      private

      def switch_via_env(rubies_root, version)
        base = extract_jruby_rbenv_options!(version)
        if ruby_root = ruby_root(rubies_root, version)
          gem_home = Dir["#{ruby_root}/lib/ruby/gems/*"].first
          base.merge(
            "PATH" => "#{ruby_root}/bin:#{ENV["PATH"]}",
            "GEM_HOME" => gem_home,
            "GEM_PATH" => gem_home
          )
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
        Dir.glob("#{root}/*").detect do |p|
          File.basename(p).sub(/^ruby-/,"").start_with?(version)
        end
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
          { "JRUBY_OPTS" => "--1.9" }
        elsif version.sub!("-d18", "")
          { "JRUBY_OPTS" => "--1.8" }
        else
          {}
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
    end
  end
end
