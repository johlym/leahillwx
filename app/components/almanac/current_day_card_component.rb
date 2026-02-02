# frozen_string_literal: true

class Almanac::CurrentDayCardComponent < ViewComponent::Base
  include DateTimeFormatting

  def initialize(entry:, dynamic_positions:, location:)
    @entry = entry
    @dynamic_positions = dynamic_positions
    @location = location
  end

  private

  attr_reader :entry, :dynamic_positions, :location

  def current_time
    Time.current.strftime("%I:%M %p")
  end

  def moon_heading
    return "N/A" unless dynamic_positions && dynamic_positions[:moon]
    azimuth = dynamic_positions[:moon][:azimuth]
    heading_from_azimuth(azimuth)
  end

  def heading_from_azimuth(azimuth)
    directions = [ "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                  "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" ]
    index = ((azimuth + 11.25) / 22.5).floor % 16
    "#{directions[index]} (#{azimuth.round(0)}°)"
  end
end
