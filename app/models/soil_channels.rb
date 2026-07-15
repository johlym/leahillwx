# frozen_string_literal: true

# Site-configured friendly names for soil sensor channels.
# Edit config/soil_channels.yml; unnamed channels fall back to "Ch N".
class SoilChannels
  CONFIG_PATH = Rails.root.join("config/soil_channels.yml")

  class << self
    attr_writer :config_path

    def config_path
      @config_path || CONFIG_PATH
    end

    def name_for(channel)
      channel = Integer(channel, exception: false)
      return nil unless channel

      names[channel] || default_name(channel)
    end

    def default_name(channel)
      "Ch #{channel}"
    end

    def names
      @names ||= load_names
    end

    def reload!
      @names = nil
      names
    end

    private

    def load_names
      return {} unless File.exist?(config_path)

      raw = YAML.load_file(config_path)
      return {} unless raw.is_a?(Hash)

      raw.each_with_object({}) do |(key, value), hash|
        channel = Integer(key, exception: false)
        next if channel.nil? || value.blank?

        hash[channel] = value.to_s.strip
      end
    end
  end
end
