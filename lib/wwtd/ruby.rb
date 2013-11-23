module WWTD
  module Ruby
    class << self
      def available?(version)
        !version || switch_statement(version)
      end

      def switch_statement(version)
        return unless version
        version = normalize_ruby_version(version)
        if rvm_executable
          command = "rvm #{version} do "
          command if cache_command("#{command} ruby -v")
        else
          if ruby_root = ENV["RUBY_ROOT"] # chruby or RUBY_ROOT set
            switch_path(File.dirname(ruby_root), version)
          elsif rbenv_executable
            rubies_root = cache_command("which rbenv").sub(%r{/(\.?rbenv)/.*}, "/\\1") + "/versions"
            switch_path(rubies_root, version)
          end
        end
      end

      private

      def switch_path(rubies_root, version)
        extract_jruby_rbenv_options!(version)
        if ruby_root = ruby_root(rubies_root, version)
          gem_home = Dir["#{ruby_root}/lib/ruby/gems/*"].first
          ENV["PATH"] = "#{ruby_root}/bin:#{ENV["PATH"]}"
          ENV["GEM_HOME"] = ENV["GEM_PATH"] = gem_home
          ""
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
    end
  end
end
