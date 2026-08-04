# frozen_string_literal: true

class Home::CurrentWeather::ConditionsComponent < ViewComponent::Base
  def initialize(
    current:,
    almanac:,
    today_forecast: nil,
    current_forecast: nil,
    today_peaks: {},
    aqi: nil,
    hourly_ranges: {},
    wildfire: nil,
    aurora: nil,
    planet_night: nil,
    iss_pass: nil
  )
    @current = current
    @almanac = almanac
    @today_forecast = today_forecast
    @current_forecast = current_forecast
    @today_peaks = today_peaks || {}
    @aqi = aqi
    @hourly_ranges = hourly_ranges || {}
    @wildfire = wildfire
    @aurora = aurora
    @planet_night = planet_night
    @iss_pass = iss_pass
  end

  attr_reader :today_peaks, :aqi, :hourly_ranges, :wildfire, :aurora, :planet_night, :iss_pass

  def season
    @almanac.season
  end

  def current_temperature
    @current.temperature.to_fahrenheit.round(0)
  end

  def current_feels_like
    @current.feels_like.to_fahrenheit.round(0)
  end

  def current_wind_speed
    @current.wind_speed_mph.round(0)
  end

  WIND_DIRECTIONS = %w[
  N NNE NE ENE E ESE SE SSE
  S SSW SW WSW W WNW NW NNW
].freeze

  def current_wind_direction
    degrees = @current.wind_dir
    return if degrees.nil?

    normalized_degrees = degrees.to_f % 360
    index = ((normalized_degrees + 11.25) / 22.5).floor % 16

    WIND_DIRECTIONS[index]
  end

  def current_gust_speed
    @current.gust_speed_mph.round(0)
  end

  def current_humidity
    @current.humidity
  end

  def current_uvi
    @current.uvi.round(0)
  end

  def current_solar_irradiance
    @current.uv.round(0)
  end

  def current_uv_index_category
    uv_value = @current.uvi.to_i
    case uv_value
    when 0..2
      "Low"
    when 3..5
      "Moderate"
    when 6..7
      "High"
    when 8..10
      "Very High"
    else
      "Extreme"
    end
  end

  def uv_badge_class
    case @current.uvi.to_i
    when 0..2 then "status-badge-success"
    when 3..5 then "status-badge-warning"
    else "status-badge-danger"
    end
  end

  def uv_fill_class
    case @current.uvi.to_i
    when 0..2 then "bg-emerald-500"
    when 3..5 then "bg-amber-400"
    when 6..7 then "bg-orange-500"
    else "bg-red-500"
    end
  end

  def reading_timestamp_header
    Time.current.in_time_zone("America/Los_Angeles").strftime("%b %-d, %Y @ %-I:%M %p").upcase
  end

  def current_rain_day
    format("%.2f", @current.rain_day_in)
  end

  def current_rain_hour
    format("%.2f", @current.rain_rate_in)
  end

  def current_dew_point
    @current.dew_point.to_fahrenheit.round(0)
  end

  def reading_timestamp
    Time.current.in_time_zone("America/Los_Angeles").strftime("%b %-d, %Y @ %-I:%M %p")
  end

  # Rough cloud-base altitude in feet. Formula: (T_F - Td_F) × 227.3.
  # Positive spread means a base above ground; zero or negative means
  # we're effectively in cloud/fog, so we clamp at 0.
  def current_cloud_base_ft
    spread = @current.temperature.to_fahrenheit - @current.dew_point.to_fahrenheit
    return 0 if spread <= 0
    (spread * 227.3).round(-2)
  end

  # UV Index scale is 0..12+. Convert to 0..1 position on the color bar.
  def uv_marker_position
    ((@current.uvi.to_f / 12.0) * 100.0).clamp(0.0, 100.0).round(1)
  end

  def today_high
    @today_forecast&.temp_max&.round(0)
  end

  def today_low
    @today_forecast&.temp_min&.round(0)
  end

  def weather_icon
    @current_forecast&.weather_icon || "01d"
  end

  def weather_description
    @current_forecast&.weather_description&.titleize || "Clear"
  end

  def night_time?
    return false unless @current&.reading_date_time && @almanac

    !@current.reading_date_time.between?(@almanac.sunrise_at, @almanac.sunset_at)
  end
end
