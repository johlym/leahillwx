# frozen_string_literal: true

# Homepage "peak today" lines under live cards.
# Reuses LiveCardHourlyRanges bucket highs (already one day scan) instead of
# issuing separate MAX(...) queries per metric.
module WeatherData
  class TodayPeaks
    def self.from_hourly_ranges(hourly_ranges)
      new(hourly_ranges).call
    end

    def initialize(hourly_ranges)
      @hourly_ranges = hourly_ranges || {}
    end

    def call
      {
        dew_point_f: peak(:dew_point),
        wind_gust_mph: peak(:wind),
        uvi: peak(:uvi),
        humidity: peak(:humidity),
        rain_rate_in: peak(:rain_rate),
        pressure_hpa: peak(:pressure)
      }
    end

    private

    attr_reader :hourly_ranges

    def peak(metric)
      hourly_ranges.dig(metric, :y_max)
    end
  end
end
