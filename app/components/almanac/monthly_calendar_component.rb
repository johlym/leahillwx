# frozen_string_literal: true

class Almanac::MonthlyCalendarComponent < ViewComponent::Base
  include DateTimeFormatting

  def initialize(month_date:, entries:, today:)
    @month_date = month_date
    @entries = entries
    @today = today
  end

  private

  attr_reader :month_date, :entries, :today

  def days_in_month
    start_date = month_date.beginning_of_month
    end_date = month_date.end_of_month
    (start_date..end_date).to_a
  end

  def entry_for_date(date)
    entries[date]
  end

  def is_today?(date)
    date == today
  end

  def km_to_miles(km)
    return nil unless km
    km * 0.621371
  end

  def azimuth_at_time(positions, time)
    return nil unless positions.present? && time
    minute = time.hour * 60 + time.min
    sample = positions.find { |s| s["m"] == minute }
    sample ? sample["az"] : nil
  end

  # Get all moon events for a day in chronological order
  # Returns array of hashes: [{ type: :rise/:set, time: Time, azimuth: Float }, ...]
  def moon_events_for_day(entry)
    return [] unless entry

    events = []

    # Add moonrise if present
    if entry.moonrise_at
      events << {
        type: :rise,
        time: entry.moonrise_at,
        azimuth: azimuth_at_time(entry.moon_positions_1min, entry.moonrise_at)
      }
    end

    # Add moonset if present
    if entry.moonset_at
      events << {
        type: :set,
        time: entry.moonset_at,
        azimuth: azimuth_at_time(entry.moon_positions_1min, entry.moonset_at)
      }
    end

    # Sort by time to ensure chronological order
    events.sort_by { |e| e[:time] }
  end

  # Determine column offset for a day's events
  # Returns 0 (start at column 1) or 1 (start at column 2)
  def column_offset_for_date(date, entry)
    return 0 unless entry

    # If only moonset (no moonrise), offset by 1 so it appears in column 2
    if entry.moonset_at && !entry.moonrise_at
      return 1
    end

    # If only moonrise (no moonset), no offset so it appears in column 1
    if entry.moonrise_at && !entry.moonset_at
      return 0
    end

    # If both exist and moonrise comes after moonset, use columns 2/3
    if entry.moonrise_at && entry.moonset_at
      return entry.moonrise_at > entry.moonset_at ? 1 : 0
    end

    # Default: no offset
    0
  end

  def moon_rise_azimuth(entry)
    azimuth_at_time(entry.moon_positions_1min, entry.moonrise_at)
  end

  def moon_set_azimuth(entry)
    azimuth_at_time(entry.moon_positions_1min, entry.moonset_at)
  end

  def moon_transit_azimuth(entry)
    azimuth_at_time(entry.moon_positions_1min, entry.moon_transit_at)
  end

  def sun_rise_azimuth(entry)
    azimuth_at_time(entry.sun_positions_1min, entry.sunrise_at)
  end

  def sun_set_azimuth(entry)
    azimuth_at_time(entry.sun_positions_1min, entry.sunset_at)
  end

  def sun_transit_azimuth(entry)
    azimuth_at_time(entry.sun_positions_1min, entry.solar_noon_at)
  end

  def format_day_length(seconds)
    return nil unless seconds
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    secs = seconds % 60
    "#{hours}:#{minutes.to_s.rjust(2, '0')}:#{secs.to_s.rjust(2, '0')}"
  end

  def format_day_length_diff(seconds)
    return nil unless seconds
    abs_seconds = seconds.abs
    minutes = abs_seconds / 60
    secs = abs_seconds % 60
    sign = seconds >= 0 ? "+" : "-"
    "#{sign}#{minutes}:#{secs.to_s.rjust(2, '0')}"
  end

  def sun_transit_altitude(entry)
    return nil unless entry.solar_noon_at && entry.sun_positions_1min.present?
    # Convert to local timezone before calculating minute offset
    local_time = entry.solar_noon_at.in_time_zone("America/Los_Angeles")
    minute = local_time.hour * 60 + local_time.min
    sample = entry.sun_positions_1min.find { |s| s["m"] == minute }
    sample ? sample["alt"] : nil
  end

  def heading_from_azimuth(azimuth)
    return nil unless azimuth
    directions = [ "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                  "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW" ]
    index = ((azimuth + 11.25) / 22.5).floor % 16
    directions[index]
  end

  def format_distance(km)
    return "N/A" unless km
    if km > 1_000_000
      "#{(km / 1_000_000).round(2)} million km"
    else
      "#{km.round(0).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} km"
    end
  end

  def moon_transit_altitude(entry)
    return nil unless entry.moon_transit_at && entry.moon_positions_1min.present?
    minute = entry.moon_transit_at.hour * 60 + entry.moon_transit_at.min
    sample = entry.moon_positions_1min.find { |s| s["m"] == minute }
    sample ? sample["alt"] : nil
  end

  def sample_positions(positions, interval: 60)
    return [] unless positions.present?
    positions.select.with_index { |_, i| i % interval == 0 || i == positions.length - 1 }
             .map { |pos| { m: pos["m"], alt: pos["alt"] } }
  end

  def distance_miles(km, int)
    return nil unless km
    (km_to_miles(km) / int).round(2)
  end
end
