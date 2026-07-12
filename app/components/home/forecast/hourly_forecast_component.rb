# frozen_string_literal: true

class Home::Forecast::HourlyForecastComponent < ViewComponent::Base
  attr_reader :hours, :timestamp

  def initialize(hours:, timestamp:)
    @hours = hours || []
    @timestamp = timestamp
  end

  def formatted_timestamp
    timestamp.in_time_zone("America/Los_Angeles").strftime("%b %d, %y @ %I:%M %p")
  end

  def night_time?(hour_time)
    return false unless hour_time

    almanac = AlmanacEntry.find_by(date: hour_time.to_date)
    return false unless almanac&.sunrise_at && almanac&.sunset_at

    hour_time < almanac.sunrise_at || hour_time > almanac.sunset_at
  end
end
