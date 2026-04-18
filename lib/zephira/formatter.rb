# frozen_string_literal: true

module Zephira
  class Formatter
    FORMAT_STRINGS = {
      color_white: "\e[37m",
      color_red: "\e[31m",
      color_dark_red: "\e[91m",
      color_green: "\e[32m",
      color_grey: "\e[90m",
      format_bold: "\e[1m",
      format_italic: "\e[3m",
      format_underlined: "\e[4m",
      format_strikethrough: "\e[9m",
      format_bold_italic: "\e[1;3m",
      format_bold_underlined: "\e[1;4m",
      format_italic_underlined: "\e[3;4m",
      format_bold_strikethrough: "\e[1;9m",
      format_italic_strikethrough: "\e[3;9m",
      format_underlined_strikethrough: "\e[4;9m",
      format_clear: "\e[0m"
    }.freeze

    class << self
      def format(string, indent: 0)
        raise ArgumentError, "Indent must be a non-negative integer" unless indent.is_a?(Integer) && indent >= 0

        string.each_line.map do |line|
          indented_line = (" " * indent) + line.chomp

          FORMAT_STRINGS.each do |key, value|
            indented_line.gsub!("###{key.upcase}##", value)
          end

          # replace any remaining format strings with the clear format
          # this avoids having malformed format strings left in the output
          indented_line.gsub!(/##\w+##/, style(:clear))

          indented_line
        end.join("\n")
      end

      def available_formats
        FORMAT_STRINGS.except(:format_clear).map do |key, value|
          format_string = "###{key.to_s.upcase}##"
          description = "#{key.to_s.split("_")[1..].join(" ")} text"
          "#{format_string} for #{description}"
        end + ["##FORMAT_CLEAR## to clear all formatting"]
      end

      def color(color, string = nil)
        color_code = FORMAT_STRINGS[:"color_#{color}"]
        raise ArgumentError, "Invalid color: #{color}" unless color_code

        return color_code if string.nil?
        "#{color_code}#{string}#{style(:clear)}"
      end

      def style(style, string = nil)
        style_code = FORMAT_STRINGS[:"format_#{style}"]
        raise ArgumentError, "Invalid style: #{style}" unless style_code

        return style_code if string.nil?
        "#{style_code}#{string}#{style(:clear)}"
      end
    end
  end
end
