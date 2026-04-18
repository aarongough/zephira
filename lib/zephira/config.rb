# frozen_string_literal: true

module Zephira
  class Config
    def self.read(key)
      return ENV[key] if ENV.key?(key)

      project_config_path = File.join(Dir.pwd, ".zephira.yml")
      if File.exist?(project_config_path)
        project_config = YAML.load_file(project_config_path)
        return project_config[key] if project_config.key?(key)
      end

      global_config_path = File.expand_path("~/.zephira.yml")
      if File.exist?(global_config_path)
        global_config = YAML.load_file(global_config_path)
        return global_config[key] if global_config.key?(key)
      end

      nil
    end
  end
end
