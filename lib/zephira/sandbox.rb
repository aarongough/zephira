# frozen_string_literal: true

require "tempfile"

module Zephira
  class Sandbox
    GHCR_IMAGE = "ghcr.io/aarongough/zephira"
    DERIVED_IMAGE_PREFIX = "zephira-sandbox"

    class << self
      def exec_if_needed!(argv)
        return unless sandbox_enabled?

        target = resolve_image
        $stderr.puts "[Zephira] Launching in Docker sandbox (#{target})..."
        Kernel.exec(*build_docker_command(argv, target))
      end

      private

      def sandbox_enabled?
        return false if ENV["ZEPHIRA_IN_DOCKER"] == "1"

        val = Config.read("ZEPHIRA_SANDBOX")
        return false if val == "false" || val == false

        docker_available?
      end

      def docker_available?
        system("docker info > /dev/null 2>&1")
      end

      def resolve_image
        base = Config.read("ZEPHIRA_BASE_IMAGE")
        return "#{GHCR_IMAGE}:#{VERSION}" unless base

        derived = derived_image_name(base)
        unless image_exists?(derived)
          $stderr.puts "[Zephira] Building sandbox image from #{base}..."
          build_derived_image(base, derived)
        end
        derived
      end

      def derived_image_name(base_image)
        sanitized = base_image.gsub(/[^a-zA-Z0-9._-]/, "-")
        "#{DERIVED_IMAGE_PREFIX}-#{sanitized}:#{VERSION}"
      end

      def image_exists?(name)
        system("docker image inspect #{name} > /dev/null 2>&1")
      end

      def build_derived_image(base_image, target_name)
        content = "FROM #{base_image}\nRUN gem install zephira:#{VERSION} --no-document\n"
        Tempfile.create(["zephira-sandbox", ".dockerfile"]) do |f|
          f.write(content)
          f.flush
          system("docker build -t #{target_name} -f #{f.path} .")
        end
      end

      def build_docker_command(argv, image)
        cmd = ["docker", "run", "--rm", "-i"]
        cmd << "-t" if $stdout.tty?

        cmd += ["-e", "ZEPHIRA_IN_DOCKER=1"]
        cmd += ["-v", "#{Dir.pwd}:/workspace:rw"]

        global_config = File.expand_path("~/.zephira.yml")
        cmd += ["-v", "#{global_config}:/root/.zephira.yml:ro"] if File.exist?(global_config)

        global_dir = File.expand_path("~/.zephira")
        cmd += ["-v", "#{global_dir}:/root/.zephira:ro"] if File.exist?(global_dir) && File.directory?(global_dir)

        %w[ZEPHIRA_API_KEY ZEPHIRA_MODEL ZEPHIRA_BASE_URL ZEPHIRA_BACKEND].each do |key|
          cmd += ["-e", "#{key}=#{ENV[key]}"] if ENV[key]
        end

        cmd += ["-w", "/workspace"]
        cmd << image
        cmd += ["zephira"] + argv
        cmd
      end
    end
  end
end
