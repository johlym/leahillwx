# frozen_string_literal: true

# Site-configured friendly names for soil moisture and temperature probe channels.
# Edit config/soil_channels.yml; unnamed channels fall back to "Ch N" / "Temp Ch N".
class SoilChannels
  CONFIG_PATH = Rails.root.join("config/soil_channels.yml")
  MAX_CHANNEL = 8

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

    # Deprecated: soil-only lookup kept for callers that have not switched yet.
    def name_for(channel)
      name_for_soil(channel)
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
          next if name.blank? || !body.is_a?(Hash)

          body = body.stringify_keys
          assign_channel_name(maps[:soil], body["soil"], name)
          assign_channel_name(maps[:temp_probe], body["temp_probe"], name)
        end
      end
    end

    def assign_channel_name(map, raw_channel, name)
      channel = Integer(raw_channel, exception: false)
      return if channel.nil? || !(1..MAX_CHANNEL).cover?(channel)

      map[channel] = name
    end
  end
end
