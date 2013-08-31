require "wwtd/version"
require "optparse"
require "yaml"

module WWTD
  CONFIG = ".travis.yml"

  class << self
    def run(argv)
      parse_options(argv)
      config = (File.exist?(CONFIG) ? YAML.load_file(CONFIG) : {})

      gemfile = config["gemfile"] || "Gemfile"
      ENV["BUNDLE_GEMFILE"] = gemfile

      default_command = (File.exist?(gemfile) ? "bundle exec rake" : "rake")
      command = config["script"] || default_command
      rvm = "rvm #{config["rvm"]} do " if config["rvm"]
      command = "#{rvm}#{command}"

      if File.exist?(gemfile)
        default_bundler_args = (File.exist?("#{gemfile}.lock") ? "--deployment" : "")
        sh "#{rvm}bundle install #{config["bundler_args"] || default_bundler_args}".strip
      end
      exec(command)
    end

    private

    # http://grosser.it/2010/12/11/sh-without-rake/
    def sh(cmd)
      puts cmd
      IO.popen(cmd) do |pipe|
        while str = pipe.gets
          puts str
        end
      end
      $?.success?
    end

    def parse_options(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = <<-BANNER.gsub(/^ {10}/, "")
            Travis simulator so you do not need to wait for the build.

            Usage:
                wwtd

            Options:
        BANNER
        opts.on("-h", "--help", "Show this.") { puts opts; exit }
        opts.on("-v", "--version", "Show Version"){ puts WWTD::VERSION; exit}
      end.parse!(argv)
      options
    end
  end
end
