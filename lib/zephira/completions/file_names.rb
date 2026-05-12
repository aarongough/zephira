# frozen_string_literal: true

module Zephira
  class Completions
    class FileNames
      def self.complete(input:, agent:)
        return [] unless input.start_with?("@")

        prefix = input[1..]
        pattern = if prefix.include?("/")
          prefix.end_with?("/") ? "#{prefix}*" : File.join(File.dirname(prefix), "#{File.basename(prefix)}*")
        else
          "#{prefix}*"
        end

        Dir.glob(pattern).map do |path|
          "@#{path}#{"/" if File.directory?(path)}"
        end
      end
    end
  end
end
