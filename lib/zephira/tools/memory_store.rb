# frozen_string_literal: true

require "fileutils"
require "yaml"

module Zephira
  class Tools
    # Shared YAML-backed key/value store used by the memory_* tools. Values are
    # always strings; loaded with safe_load to refuse arbitrary object
    # deserialization since memory is agent/user-supplied content.
    class MemoryStore
      PATH = ".zephira/memory.yml"

      def self.load
        return {} unless ::File.exist?(PATH)
        YAML.safe_load_file(PATH) || {}
      end

      def self.save(memory)
        ::FileUtils.mkdir_p(::File.dirname(PATH))
        ::File.write(PATH, memory.to_yaml)
      end

      def self.read(key)
        load[key]
      end

      def self.write(key, value)
        memory = load
        memory[key] = value
        save(memory)
      end

      def self.delete(key)
        memory = load
        return false unless memory.key?(key)
        memory.delete(key)
        save(memory)
        true
      end

      def self.key?(key)
        load.key?(key)
      end

      def self.keys
        load.keys
      end
    end
  end
end
