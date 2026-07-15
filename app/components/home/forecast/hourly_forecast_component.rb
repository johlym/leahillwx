# frozen_string_literal: true

class Home::Forecast::HourlyForecastComponent < ViewComponent::Base
  attr_reader :hours, :timestamp

  def initialize(hours:, timestamp:, almanac_by_date: nil)
    @hours = hours || []
    @timestamp = timestamp
    @almanac_by_date = almanac_by_date || preload_almanac_by_date
  end

  def formatted_timestamp
    timestamp.in_time_zone("America/Los_Angeles").strftime("%b %d, %Y @ %I:%M %p")
  end

  def night_time?(hour_time)
    return false unless hour_time

    almanac = @almanac_by_date[hour_time.to_date]
    return false unless almanac&.sunrise_at && almanac&.sunset_at

    hour_time < almanac.sunrise_at || hour_time > almanac.sunset_at
  end

  private

  def preload_almanac_by_date
    dates = @hours.filter_map { |hour| hour.time&.to_date }.uniq
    return {} if dates.empty?

    AlmanacEntry.where(date: dates).index_by(&:date)
  end
end
