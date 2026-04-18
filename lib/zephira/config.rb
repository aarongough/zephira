# frozen_string_literal: true

module Zephira
  class Config
    def self.read(key)
      project_config_path = File.join(Dir.pwd, ".zephira.yml")
      global_config_path = File.expand_path("~/.zephira.yml")

      project_config = File.exist?(project_config_path) ? YAML.load_file(project_config_path)[key] : nil
      global_config = File.exist?(global_config_path) ? YAML.load_file(global_config_path)[key] : nil

      ENV[key] || project_config || global_config
    end
  end
end
