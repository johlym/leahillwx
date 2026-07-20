# frozen_string_literal: true

# Site-configured friendly names for soil moisture and temperature probe channels.
# Edit config/soil_channels.yml; unnamed channels fall back to "Ch N" / "Temp Ch N".
class SoilChannels
  CONFIG_PATH = Rails.root.join("config/soil_channels.yml")
  MAX_CHANNEL = WeatherMeasurement::MAX_SOIL_CHANNELS

  class << self
    attr_writer :config_path

    def config_path
      @config_path || CONFIG_PATH
    end

    def name_for_soil(channel)
      channel = Integer(channel, exception: false)
      return nil unless channel

      soil_names[channel] || default_soil_name(channel)
    end

    def name_for_temp_probe(channel)
      channel = Integer(channel, exception: false)
      return nil unless channel

      temp_probe_names[channel] || default_temp_probe_name(channel)
    end

    def default_soil_name(channel)
      "Ch #{channel}"
    end

    def default_temp_probe_name(channel)
      "Temp Ch #{channel}"
    end

    def soil_names
      @soil_names ||= load_maps[:soil]
    end

    def temp_probe_names
      @temp_probe_names ||= load_maps[:temp_probe]
    end

    def reload!
      @soil_names = nil
      @temp_probe_names = nil
      @maps = nil
      soil_names
      temp_probe_names
    end

    private

    def load_maps
      @maps ||= begin
        empty = { soil: {}, temp_probe: {} }
        return empty unless File.exist?(config_path)

        raw = YAML.load_file(config_path)
        return empty unless raw.is_a?(Hash)

        raw.each_with_object({ soil: {}, temp_probe: {} }) do |(name, body), maps|
          name = name.to_s.strip
          next if name.blank?

          unless body.is_a?(Hash)
            raise ArgumentError,
              "Invalid soil_channels.yml entry #{name.inspect}: expected a mapping with " \
              "`soil:` and/or `temp_probe:` keys (legacy `#{name}: #{body}` channel-keyed " \
              "format is no longer supported)"
          end

          body = body.stringify_keys
          assign_channel_name(maps[:soil], body["soil"], name, kind: "soil")
          assign_channel_name(maps[:temp_probe], body["temp_probe"], name, kind: "temp_probe")
        end
      end
    end

    def assign_channel_name(map, raw_channel, name, kind:)
      return if raw_channel.nil?

      channel = Integer(raw_channel, exception: false)
      unless channel && (1..MAX_CHANNEL).cover?(channel)
        raise ArgumentError,
          "Invalid soil_channels.yml #{kind} channel for #{name.inspect}: " \
          "expected integer 1–#{MAX_CHANNEL}, got #{raw_channel.inspect}"
      end

      if map.key?(channel)
        raise ArgumentError,
          "Invalid soil_channels.yml: #{kind} channel #{channel} is already mapped to " \
          "#{map[channel].inspect} (cannot also map to #{name.inspect})"
      end

      map[channel] = name
    end
  end
end
