# frozen_string_literal: true

class Home::CurrentWeather::Pm25Component < ViewComponent::Base
  def initialize(current:)
    @current = current
  end

  def render?
    true
  end

  def pm25_display
    return "—" unless @current&.pm2_5

    format("%.1f", @current.pm2_5)
  end

  def category
    @current&.epa_category || "No data"
  end

  def marker_position
    @current&.aqi_marker_position || 0.0
  end

  def stale?
    @current.nil? || @current.stale?
  end

  def as_of_label
    return "No recent reading" unless @current&.observed_at

    zone = "America/Los_Angeles"
    stamp = @current.observed_at.in_time_zone(zone).strftime("%b %-d, %-I:%M %p %Z")
    stale? ? "Stale · as of #{stamp}" : "as of #{stamp}"
  end

  def source_label
    case @current&.source
    when "airnow" then "AirNow · Auburn 29th St"
    when "openweather" then "OpenWeatherMap"
    else "Awaiting first reading"
    end
  end
end
