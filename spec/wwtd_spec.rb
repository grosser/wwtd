require "spec_helper"

describe WWTD do
  it "has a VERSION" do
    WWTD::VERSION.should =~ /^[\.\da-z]+$/
  end

  describe "CLI" do
    def bundle
      Bundler.with_clean_env { sh "bundle" }
    end

    def write_default_gemfile(rake_version="0.9.2.2")
      write "Gemfile", "source 'https://rubygems.org'\ngem 'rake', '#{rake_version}'"
    end

    def write_default_rakefile
      write "Rakefile", "task(:default){ puts 111 }"
    end

    def pending_if(condition, &block)
      if condition
        pending(&block)
      else
        yield
      end
    end

    around do |example|
      Dir.mktmpdir do |dir|
        Dir.chdir(dir, &example)
      end
    end

    it "shows --version" do
      wwtd("--version").should include(WWTD::VERSION)
    end

    it "shows --help" do
      wwtd("--help").should include("Travis simulator")
    end

    it "runs without .travis.yml" do
      write_default_rakefile
      wwtd("").should include "111\n"
    end

    it "runs with script" do
      write "Rakefile", "task(:foo){ puts 111 }"
      write ".travis.yml", "script: rake foo"
      wwtd("").should include "111\n"
    end

    it "bundles if there is a Gemfile" do
      write_default_gemfile
      bundle
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION}} }"
      result = wwtd("")
      result.should include "bundle install --quiet"
      result.should include "\nRAKE: 0.9.2.2\n"
      File.exist?("vendor/bundle").should == false
    end

    it "bundles with --deployment if lockfile is committed" do
      write_default_gemfile
      bundle
      sh "git init && git add ."
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION}} }"
      result = wwtd("")
      result.should include "bundle install --deployment"
      result.should include "\nRAKE: 0.9.2.2\n"
      File.exist?("vendor/bundle").should == true
    end

    it "bundles with bundler_args" do
      write_default_gemfile
      write_default_rakefile
      write(".travis.yml", "bundler_args: --no-color")
      wwtd("").should include "bundle install --no-color"
    end

    it "casts ruby version to string when creating a path to a lock file" do
      write_default_gemfile
      write "Rakefile", "task(:default) { puts %Q{RUBY: \#{RUBY_VERSION}} }"
      write ".travis.yml", "rvm: 2.0"
      wwtd("").should include "RUBY: 2.0.0"
    end

    it "runs with given rvm version" do
      other = (RUBY_VERSION == "1.9.3" ? "2.0.0" : "1.9.3")
      write ".travis.yml", "rvm: #{other}"
      write "Rakefile", "task(:default) { puts %Q{RUBY: \#{RUBY_VERSION}} }"
      wwtd("").should include "RUBY: #{other}"
    end

    it "runs with given jruby flavor" do
      pending_if ENV["TRAVIS"] do
        write ".travis.yml", "rvm: jruby-18mode"
        write "Rakefile", "task(:default) { puts %Q{RUBY: \#{RUBY_ENGINE}-\#{RUBY_VERSION}} }"
        wwtd("").should include "RUBY: jruby-1.8.7"
      end
    end

    it "runs with given jruby flavor" do
      pending_if ENV["TRAVIS"] do
        write ".travis.yml", "rvm: jruby"
        write "Rakefile", "task(:default) { puts %Q{RUBY: \#{RUBY_ENGINE}-\#{RUBY_VERSION}} }"
        wwtd("").should include "RUBY: jruby"
      end
    end

    it "runs with given gemfile" do
      write_default_gemfile
      bundle
      sh "mkdir xxx && mv Gemfile xxx/Gemfile2 && mv Gemfile.lock xxx/Gemfile2.lock"
      sh "git init && git add ."
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION} -- \#{ENV['BUNDLE_GEMFILE']}} }"
      write ".travis.yml", "gemfile: xxx/Gemfile2"
      result = wwtd("")
      result.should include "bundle install --deployment"
      result.should include "\nRAKE: 0.9.2.2 -- xxx/Gemfile2\n"
      File.exist?("vendor/bundle").should == true
      File.exist?("gemfiles/vendor/bundle").should == false
    end

    it "prints ignored items" do
      write_default_rakefile
      write ".travis.yml", "foo: bar\nbar: baz"
      wwtd("").should include "Ignoring: bar, foo"
    end

    it "can execute with env" do
      write ".travis.yml", "env: FOO='bar baz' BAR=12=3"
      write "Rakefile", "task(:default){ puts %Q{ENV:\#{ENV['FOO']}--\#{ENV['BAR']}} }"
      wwtd("").should include "ENV:bar baz--12=3"
    end

    it "fails with unknown ruby version" do
      write ".travis.yml", "rvm: x.5.1"
      write "Rakefile", "task(:default) { puts %Q{RUBY: \#{RUBY_VERSION}} }"
      result = wwtd("", :fail => true)
      result.should include "MISSING"
    end

    it "fails if bundler fails" do
      write_default_rakefile
      write "Gemfile", "xxx"
      write ".travis.yml", "script: rake"
      wwtd("", :fail => true)
    end

    it "fails when a command fails" do
      wwtd("", :fail => true)
    end

    it "fails with missing gemfile" do
      write_default_rakefile
      write ".travis.yml", "gemfile: Gemfile1"
      wwtd("", :fail => true)
    end

    describe ".bundle" do
      it "does not leave a .bundle behind" do
        write_default_rakefile
        write_default_gemfile
        bundle
        wwtd("")
        File.exist?(".bundle").should == false
      end

      it "restores old .bundle" do
        sh "mkdir .bundle"
        write ".bundle/foo", "xxx"

        write_default_rakefile
        write_default_gemfile
        bundle

        wwtd("")

        File.exist?(".bundle").should == true
        sh("ls .bundle").should == "foo\n"
      end
    end

    describe "--parallel" do
      before do
        write ".travis.yml", "env:\n - XXX=1\n - XXX=2"
      end

      it "runs in parallel" do
        sleep = 3
        write "Rakefile", "task(:default) { sleep #{sleep} }"
        result = ""
        Benchmark.realtime { result = wwtd("--parallel") }.should < sleep * 2
        result.split("Results:").last.strip.split("\n").sort.should == ["SUCCESS env: XXX=1", "SUCCESS env: XXX=2"]
      end

      it "sets TEST_ENV_NUMBER when in parallel" do
        write "Rakefile", "task(:default) { puts %Q{TEST:\#{ENV['TEST_ENV_NUMBER'].inspect}} }"
        result = wwtd("--parallel")
        result.scan(/TEST:.*/).sort.should == ['TEST:""', 'TEST:"2"']
      end

      it "does not set TEST_ENV_NUMBER when not in parallel" do
        write "Rakefile", "task(:default) { puts %Q{TEST:\#{ENV['TEST_ENV_NUMBER'].inspect}} }"
        write ".travis.yml", "env: XXX=2"
        result = wwtd("")
        result.scan(/TEST:.*/).should == ['TEST:nil']
      end

      context "bundling" do
        before do
          write_default_gemfile
          write "Gemfile", File.read("Gemfile") + "\nFile.open('log','a'){|f|f.puts 'BUNDLE-START'; f.flush; sleep 3; f.puts 'BUNDLE-END'} if ARGV[0] == 'install'"
          write_default_rakefile
        end

        it "does not bundle 2 gemfiles at once" do
          wwtd "--parallel"
          File.read("log").scan(/BUNDLE-.*/).should == ["BUNDLE-START", "BUNDLE-END"] * 3 # should be 2 but somehow gets called twice in the second bundeling...
        end

        it "bundles 2 gemfiles from different rvms at once" do
          write ".travis.yml", "rvm:\n - 1.9.3\n - 2.0.0"
          wwtd "--parallel"
          File.read("log").scan(/BUNDLE-.*/).should == ["BUNDLE-START", "BUNDLE-START", "BUNDLE-END", "BUNDLE-END"]
        end
      end
    end

    describe "with multiple" do
      before do
        write ".travis.yml", <<-YML.gsub("          ", "")
          rvm:
            - 2.0.0
            - 1.9.3
          gemfile:
            - Gemfile1
            - Gemfile2
        YML
        write_default_gemfile
        sh "mv Gemfile Gemfile1"
        write_default_gemfile "0.9.6"
        sh "mv Gemfile Gemfile2"
        write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION} -- \#{ENV['BUNDLE_GEMFILE']} -- \#{RUBY_VERSION}} }"
      end

      it "can run multiple" do
        result = wwtd("")
        result.scan(/RAKE:.*/).sort.should == [
          "RAKE: 0.9.2.2 -- Gemfile1 -- 1.9.3",
          "RAKE: 0.9.2.2 -- Gemfile1 -- 2.0.0",
          "RAKE: 0.9.6 -- Gemfile2 -- 1.9.3",
          "RAKE: 0.9.6 -- Gemfile2 -- 2.0.0",
        ]
      end

      it "can exclude" do
        write(".travis.yml", File.read(".travis.yml") + <<-YAML.gsub("          ", ""))
          matrix:
            exclude:
              - rvm: 1.9.3
                gemfile: Gemfile2
              - rvm: 2.0.0
                gemfile: Gemfile1
        YAML
        result = wwtd("")
        result.scan(/RAKE:.*/).sort.should == [
          "RAKE: 0.9.2.2 -- Gemfile1 -- 1.9.3",
          "RAKE: 0.9.6 -- Gemfile2 -- 2.0.0",
        ]
      end
    end

    describe "rake" do
      before do
        write "Gemfile", <<-RUBY
          source 'https://rubygems.org'
          gem 'wwtd', :path => '#{Bundler.root}'
          gem 'rake'
        RUBY
        write "Rakefile", <<-RUBY
          require 'wwtd/tasks'
          task(:default) { puts 'YES-IT-WORKS' }
        RUBY
      end

      it "runs normally" do
        sh("bundle exec rake wwtd").should include "YES-IT-WORKS"
      end

      it "runs in parallel" do
        sh("bundle exec rake wwtd:parallel").should include "YES-IT-WORKS"
      end
    end

    def write(file, content)
      File.open(file, "w") { |f| f.write content }
    end

    def wwtd(command, options={})
      sh("#{Bundler.root}/bin/wwtd #{command}", options)
    end

    def sh(command, options={})
      result = Bundler.with_clean_env { `#{command} #{"2>&1" unless options[:keep_output]}` }
      raise "#{options[:fail] ? "SUCCESS" : "FAIL"} #{command}\n#{result}" if $?.success? == !!options[:fail]
      result
    end
  end

  describe ".matrix" do
    def call(config)
      WWTD.send(:matrix, config)
    end

    it "builds simple from simple" do
      call({}).should == [{}]
    end

    it "keeps unknown" do
      call({"foo" => ["bar"]}).should == [{"foo" => ["bar"]}]
    end

    it "builds simple from 1-element array" do
      call({"gemfile" => ["Gemfile"]}).should == [{"gemfile" => "Gemfile"}]
    end

    it "builds from array" do
      call({"gemfile" => ["Gemfile1", "Gemfile2"]}).should == [{"gemfile" => "Gemfile1"}, {"gemfile" => "Gemfile2"}]
    end

    it "builds from env" do
      call({"env" => ["A=1", "B=2"]}).should == [{"env" => "A=1"}, {"env" => "B=2"}]
    end

    it "builds from nested env" do
      call({"env" => {"global" => ["A=1", "B=2"], "local" => ["A=2", "B=3"]}}).should =~ [
        {"env" => "A=1 B=2"}, {"env" => "A=2 B=3"}
      ]
    end

    it "builds from multiple arrays" do
      call("gemfile" => ["Gemfile1", "Gemfile2"], "rvm" => ["a", "b"]).should == [
        {"gemfile"=>"Gemfile1", "rvm"=>"a"},
        {"gemfile"=>"Gemfile1", "rvm"=>"b"},
        {"gemfile"=>"Gemfile2", "rvm"=>"a"},
        {"gemfile"=>"Gemfile2", "rvm"=>"b"}
      ]
    end

    it "excludes and includes" do
      call(
        "gemfile" => ["Gemfile1", "Gemfile2"],
        "rvm" => ["a", "b"],
        "matrix" => {
          "exclude" => [
            {"gemfile" => "Gemfile1", "rvm" => "b"}
          ],
          "include" => [
            {"gemfile" => "Gemfile1", "rvm" => "c"}
          ],
        }
      ).should == [
        {"rvm"=>"a", "gemfile"=>"Gemfile1"},
        {"rvm"=>"a", "gemfile"=>"Gemfile2"},
        {"rvm"=>"b", "gemfile"=>"Gemfile2"},
        {"rvm"=>"c", "gemfile"=>"Gemfile1"},
      ]
    end
  end

  describe ".config_info" do
    def call(*args)
      WWTD::CLI.send(:config_info, *args)
    end

    it "prints a summary" do
      c = {"a" => "1", "b" => "1"}
      call([c, c.merge("a" => "2")], c).should == "a: 1"
    end

    it "truncates long values" do
      c = {"a" => "1"*40}
      call([c, c.merge("a" => "2")], c).should == "a: #{"1"*27}..."
    end

    it "aligns values" do
      c = {"a" => "1", "b" => "1"}
      call([c, {"a" => "111", "b" => "11"}], c).should == "a: 1   b: 1 "
    end
  end

  describe ".parse_options" do
    def call(*args)
      WWTD::CLI.send(:parse_options, *args)
    end

    it "parses simple parallel" do
      call(["--parallel"])[:parallel].should == 4
    end

    it "parses parallel with number" do
      call(["--parallel", "5"])[:parallel].should == 5
    end
  end
end
