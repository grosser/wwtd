module WWTD
  module CLI
    INFO_MAX_CHARACTERS = 30
    STATE_COLOR_MAP = {:start => :yellow, :success => :green}
    ASCII_COLORS = {:red => 31, :green => 32, :yellow => 33}

    class << self
      def run(argv=[])
        # Read travis.yml
        matrix, ignored = ::WWTD.read_travis_yml
        puts "Ignoring: #{ignored.sort.join(", ")}" if ignored.any?

        # Execute tests
        results = ::WWTD.run(matrix, parse_options(argv)) do |state, config|
          puts info_line(state, config, matrix)
        end

        # Summary
        if results.size > 1
          puts "\nResults:"
          puts results.map { |state, config| info_line(state, config, matrix) }
        end

        results.all? { |state, config| state == :success } ? 0 : 1
      end

      private

      def parse_options(argv)
        options = {}
        OptionParser.new do |opts|
          opts.banner = <<-BANNER.gsub(/^ {10}/, "")
            WWTD: Travis simulator - faster + no more waiting for build emails

            Usage:
                wwtd

            Options:
          BANNER
          opts.on("-p", "--parallel [PROCESSES]", Integer, "Run in parallel") { |c| options[:parallel] = c || Parallel.processor_count }
          opts.on("-h", "--help", "Show this.") { puts opts; exit }
          opts.on("-v", "--version", "Show Version"){ puts WWTD::VERSION; exit}
        end.parse!(argv)
        options
      end

      def info_line(state, config, matrix)
        config_info = config_info(matrix, config)
        color = STATE_COLOR_MAP[state] || :red
        "#{colorize(color, state.to_s.upcase)} #{config_info}"
      end

      # human readable config without options that are the same in all configs
      # {"a" => 1, "b" => 2} + {"a" => 2, "b" => 2} => {"a" => 1} + {"a" => 2}
      def config_info(matrix, config)
        config = config.select { |k,v| matrix.map { |c| c[k] }.uniq.size > 1 }.sort # find non-unique values aka interesting
        maximum_value_lengths = Hash[config.map { |k,v| [k, matrix.map { |h| h[k].to_s.size }.max ] }] # find maximum value length for each key so we can align
        config.map do |k, v|
          value = truncate(v, INFO_MAX_CHARACTERS).ljust([INFO_MAX_CHARACTERS, maximum_value_lengths[k]].min)
          "#{k}: #{value}"
        end.join(" ") # truncate values that are too long
      end

      def truncate(value, number)
        value = value.to_s # accidental numbers like 'rvm: 2.0'
        if value.size > number
          "#{value[0...27]}..."
        else
          value
        end
      end

      def colorize(color, string)
        if $stdout.tty?
          "\e[#{ASCII_COLORS[color]}m#{string}\e[0m"
        else
          string
        end
      end
    end
  end
end
