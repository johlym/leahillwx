# frozen_string_literal: true

class Home::CurrentWeather::SkyHazardsComponent < ViewComponent::Base
  COMPASS = Iss::PassPredictor::COMPASS

  def initialize(wildfire:, aurora:, planet_night:, iss_pass:)
    @wildfire = wildfire
    @aurora = aurora
    @planet_night = planet_night
    @iss_pass = iss_pass
  end

  def visible_planets
    return [] unless @planet_night

    @planet_night.visible_planets
  end

  def planet_bodies_for_arc
    visible_planets.filter_map do |planet|
      rise_at = planet["rise_at"]
      set_at = planet["set_at"]
      next unless rise_at && set_at

      {
        key: planet["key"],
        label: planet["label"],
        rise_at: rise_at,
        set_at: set_at,
        direction: planet["direction"]
      }
    end
  end

  def wildfire_distance
    return nil unless @wildfire

    "#{number_with_precision(@wildfire.distance_mi, precision: 0)} mi"
  end

  def wildfire_status_label
    return nil unless @wildfire

    pct = @wildfire.percent_contained
    return "Uncontained" if pct.nil? || pct < 1
    return "Contained" if pct >= 100

    "#{pct.round(0)}% contained"
  end

  def wildfire_status_badge_class
    pct = @wildfire&.percent_contained
    return "status-badge-danger" if pct.nil? || pct < 1
    return "status-badge-success" if pct >= 100

    "status-badge-warning"
  end

  def iss_direction_line
    return nil unless @iss_pass

    aos = compass_label(@iss_pass.aos_az)
    los = compass_label(@iss_pass.los_az)
    max = @iss_pass.max_el.round(0)
    "Appears #{aos} → #{max}° high → Disappears #{los}"
  end

  def iss_when
    return nil unless @iss_pass

    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    @iss_pass.aos_at.in_time_zone(zone).strftime("%a %-I:%M %p")
  end

  def iss_countdown
    return nil unless @iss_pass

    seconds = (@iss_pass.aos_at - Time.current).to_i
    return "Now" if seconds <= 0

    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    if hours > 0
      "in #{hours}h #{minutes}m"
    else
      "in #{minutes}m"
    end
  end

  def iss_duration
    return nil unless @iss_pass

    minutes = (@iss_pass.duration_s / 60.0).round
    "#{minutes} min"
  end

  def format_planet_time(iso)
    return "—" if iso.blank?

    Time.zone.parse(iso).in_time_zone("America/Los_Angeles").strftime("%-I:%M %p")
  rescue ArgumentError, TypeError
    "—"
  end

  # Rough overnight visibility share for the progress bar (rise→set
  # clipped to a 12h civil-night window). Falls back to 50% when times
  # are missing so the UI still shows an instrument-style meter.
  def planet_visibility_pct(planet)
    rise_at = parse_planet_time(planet["rise_at"])
    set_at = parse_planet_time(planet["set_at"])
    return 50 unless rise_at && set_at

    duration_h = ((set_at - rise_at) / 1.hour).abs
    ((duration_h / 12.0) * 100.0).clamp(10.0, 100.0).round
  end

  private

  def parse_planet_time(iso)
    return nil if iso.blank?

    Time.zone.parse(iso)
  rescue ArgumentError, TypeError
    nil
  end

  def compass_label(degrees)
    return "?" if degrees.nil?

    index = ((degrees.to_f % 360) + 11.25) / 22.5
    COMPASS[index.floor % 16]
  end
end
