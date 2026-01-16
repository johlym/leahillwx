# frozen_string_literal: true

class Home::Forecast::HourlyForecastComponent < ViewComponent::Base
  attr_reader :forecast, :almanac

  def initialize(forecast:, almanac:)
    @forecast = forecast
    @almanac = almanac
  end

  def formatted_timestamp
    forecast.created_at.in_time_zone("America/Los_Angeles").strftime("%B %-d, %Y @ %H:%S")
  end

  def night?(hour)
    return false unless hour.time

    local_time = hour.time.in_time_zone("America/Los_Angeles")
    hour_date = local_time.to_date
    day_almanac = AlmanacEntry.for_date(hour_date)

    return false unless day_almanac&.sunrise_at && day_almanac&.sunset_at

    sunrise_hour = day_almanac.sunrise_at.in_time_zone("America/Los_Angeles").hour
    sunset_hour = day_almanac.sunset_at.in_time_zone("America/Los_Angeles").hour

    local_time.hour <= sunrise_hour || local_time.hour >= sunset_hour
  end
end
