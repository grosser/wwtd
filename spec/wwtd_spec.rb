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
    def write_default_gemfile
      write "Gemfile", "source 'https://rubygems.org'\ngem 'rake', '0.9.2.2'"
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
      wwtd("").should == "111\n"
    end

    it "runs with script" do
      write "Rakefile", "task(:foo){ puts 111 }"
      write ".travis.yml", "script: rake foo"
      wwtd("").should == "111\n"
    end

    it "bundles with if there is a Gemfile" do
      write_default_gemfile
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION}} }"
      result = wwtd("")
      result.should include "bundle install\n"
      result.should include "\nRAKE: 0.9.2.2\n"
    end

    it "bundles with --deployment if there is a Gemfile.lock" do
      write_default_gemfile
      bundle
      write "Rakefile", "task(:default) { puts %Q{RAKE: \#{Rake::VERSION}} }"
      result = wwtd("")
      result.should include "bundle install --deployment\n"
      result.should include "\nRAKE: 0.9.2.2\n"
    end

    it "bundles with bundler_args" do
      write_default_gemfile
      write_default_rakefile
      write(".travis.yml", "bundler_args: --quiet")
      wwtd("").should include "bundle install --quiet\n"
    end

    def write(file, content)
      File.write(file, content)
    end

    def wwtd(command, options={})
      sh("#{Bundler.root}/bin/wwtd #{command}", options)
    end

    def sh(command, options={})
      result = Bundler.with_clean_env { `#{command} #{"2>&1" unless options[:keep_output]}` }
      raise "FAILED #{command}\n#{result}" if $?.success? == !!options[:fail]
      result
    end
  end
end
