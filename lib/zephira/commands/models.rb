# frozen_string_literal: true

module Zephira
  class Commands
    class Models
      class << self
        def name
          "models"
        end

        def description
          "List available models or switch: /models set MODEL_NAME"
        end

        def run(agent:, args:)
          model_classes = Zephira::Models.constants(false)
            .map { |c| Zephira::Models.const_get(c) }
            .reject { |cls| cls == Zephira::Models::BaseModel }

          if args.nil? || args.empty?
            puts "Available models:"
            model_classes.each do |m|
              marker = (m == agent.model) ? "*" : " "
              suffix = (m == agent.model) ? " (current)" : ""
              puts "  #{marker} #{m.model_name}#{suffix}"
            end
            puts
            return
          end

          parts = args.dup
          parts.shift if parts.first.to_s.casecmp("set").zero?
          model_name = parts.first

          if model_name.nil? || model_name.strip.empty?
            puts "Usage: /models set MODEL_NAME"
            return
          end

          target = model_classes.find { |m| m.model_name.downcase == model_name.downcase }

          if target
            agent.model = target
            puts "Model changed to #{target.model_name}"
          else
            puts "Unknown model '#{model_name}'. Available models:"
            model_classes.each { |m| puts "    #{m.model_name}" }
          end
        end
      end
    end
  end
end
