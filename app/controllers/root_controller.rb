class RootController < ApplicationController
  def index
    @current = WeatherMeasurement
      .select("weather_measurements.*, (SELECT COUNT(*) FROM weather_measurements) as total_count")
      .order(reading_date_time: :desc)
      .first

    @almanac = AlmanacEntry.for_date(Time.zone.today)

    forecast_record = Forecast.latest

    if forecast_record.nil? || forecast_record.created_at < 1.hour.ago
      DownloadOpenWeatherForecastJob.perform_async
    end

    @forecast = ForecastParser.new(forecast_record || {}).parse
    @earthquakes = Earthquake.last(5).reverse
    @today_peaks = compute_today_peaks
    @hourly_ranges = WeatherData::LiveCardHourlyRanges.new.call
    @aqi = Aqi.latest
  end

  def about
    @weather_measurement_count = WeatherMeasurement.count
    @first_weather_measurement = WeatherMeasurement.order(reading_date_time: :asc).first
  end

  private

  # Today's peaks across weather measurements, used by the live cards
  # to show "peaked at X earlier" in a small line under each value.
  # Returns nil for any metric whose base data isn't available.
  def compute_today_peaks
    zone = "America/Los_Angeles"
    start = Time.current.in_time_zone(zone).beginning_of_day.utc
    scope = WeatherMeasurement.where(reading_date_time: start..Time.current)
    return {} unless scope.exists?

    peak_temp_c = scope.maximum(:temperature)
    peak_dew_c = scope.maximum(Arel.sql("temperature - ((100 - humidity) / 5.0)"))
    peak_wind_mps = scope.maximum(:gust_speed)
    peak_uvi = scope.maximum(:uvi).to_i
    peak_humidity = scope.maximum(:humidity)
    peak_rain_rate_mm = scope.maximum(:rain_rate)

    {
      temperature_f: peak_temp_c ? c_to_f(peak_temp_c).round(0) : nil,
      dew_point_f: peak_dew_c ? c_to_f(peak_dew_c).round(0) : nil,
      wind_gust_mph: peak_wind_mps ? (peak_wind_mps * 2.23694).round(0) : nil,
      uvi: peak_uvi ? peak_uvi.round(1) : nil,
      humidity: peak_humidity,
      rain_rate_in: peak_rain_rate_mm ? (peak_rain_rate_mm / 25.4).round(2) : nil
    }
  end

  def c_to_f(celsius)
    celsius * 9.0 / 5.0 + 32.0
  end
end
