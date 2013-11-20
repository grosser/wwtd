module WWTD
  module Colors
    class << self
      def tint(color, string)
        if $stdout.tty?
          "\e[#{color}m#{string}\e[0m"
        else
          string
        end
      end

      def red(string)
        tint(31, string)
      end

      def green(string)
        tint(32, string)
      end

      def yellow(string)
        tint(33, string)
      end
    end
  end
end
