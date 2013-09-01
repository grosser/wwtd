require "spec_helper"
require "tmpdir"

def bundle
  Bundler.with_clean_env { sh "bundle" }
end

describe WWTD do
  it "has a VERSION" do
    WWTD::VERSION.should =~ /^[\.\da-z]+$/
  end

  describe "CLI" do
    def write_default_gemfile(rake_version="0.9.2.2")
      write "Gemfile", "source 'https://rubygems.org'\ngem 'rake', '#{rake_version}'"
    end

    def write_default_rakefile
      write "Rakefile", "task(:default){ puts 111 }"
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
      wwtd("--help").should include("Travis simulator so you do not need to wait for the build")
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
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION}} }"
      result = wwtd("")
      result.should include "bundle install --quiet\n"
      result.should include "\nRAKE: 0.9.2.2\n"
    end

    it "bundles with --deployment if there is a Gemfile.lock" do
      write_default_gemfile
      bundle
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION}} }"
      result = wwtd("")
      result.should include "bundle install --deployment --quiet\n"
      result.should include "\nRAKE: 0.9.2.2\n"
    end

    it "bundles with bundler_args" do
      write_default_gemfile
      write_default_rakefile
      write(".travis.yml", "bundler_args: --path vendor/bundle")
      wwtd("").should include "bundle install --path vendor/bundle --quiet\n"
    end

    it "runs with given rvm version" do
      other = (RUBY_VERSION == "1.9.3" ? "2.0.0" : "1.9.3")
      write ".travis.yml", "rvm: #{other}"
      write "Rakefile", "task(:default) { puts %Q{RUBY: \#{RUBY_VERSION}} }"
      wwtd("").should include "RUBY: #{other}"
    end

    it "runs with given gemfile" do
      write_default_gemfile
      bundle
      sh "mv Gemfile Gemfile2 && mv Gemfile.lock Gemfile2.lock"
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION} -- \#{ENV['BUNDLE_GEMFILE']}} }"
      write ".travis.yml", "gemfile: Gemfile2"
      result = wwtd("")
      result.should include "bundle install --deployment --quiet\n"
      result.should include "\nRAKE: 0.9.2.2 -- Gemfile2\n"
    end

    it "prints ignored items" do
      write_default_rakefile
      write ".travis.yml", "foo: bar\nbar: baz"
      wwtd("").should include "Ignoring: foo, bar"
    end

    it "can execute with env" do
      write ".travis.yml", "env: FOO='bar baz' BAR=12=3"
      write "Rakefile", "task(:default){ puts %Q{ENV:\#{ENV['FOO']}--\#{ENV['BAR']}} }"
      wwtd("").should include "ENV:bar baz--12=3"
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

    def write(file, content)
      File.write(file, content)
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

    it "builds from multiple arrays" do
      call("gemfile" => ["Gemfile1", "Gemfile2"], "rvm" => ["a", "b"]).should == [
        {"rvm"=>"a", "gemfile"=>"Gemfile1"},
        {"rvm"=>"a", "gemfile"=>"Gemfile2"},
        {"rvm"=>"b", "gemfile"=>"Gemfile1"},
        {"rvm"=>"b", "gemfile"=>"Gemfile2"},
      ]
    end

    it "excludes with" do
      call(
        "gemfile" => ["Gemfile1", "Gemfile2"],
        "rvm" => ["a", "b"],
        "matrix" => {
          "exclude" => [
            {"gemfile" => "Gemfile1", "rvm" => "b"}
          ]
        }
      ).should == [
        {"rvm"=>"a", "gemfile"=>"Gemfile1"},
        {"rvm"=>"a", "gemfile"=>"Gemfile2"},
        {"rvm"=>"b", "gemfile"=>"Gemfile2"},
      ]
    end
  end
end
