class RootController < ApplicationController
  def index
    @current = WeatherMeasurement.order(reading_date_time: :desc).first
    @measurement_total_count = WeatherMeasurements::TotalCount.read

    @almanac = AlmanacEntry.for_date(Time.zone.today)

    forecast_record = Forecast.latest

    if forecast_record.nil? || forecast_record.created_at < 1.hour.ago
      DownloadOpenWeatherForecastJob.perform_async
    end

    @forecast = ForecastParser.new(forecast_record || {}).parse
    @earthquakes = Earthquake.last(5).reverse
    @hourly_ranges = WeatherData::LiveCardHourlyRanges.new.call
    @today_peaks = WeatherData::TodayPeaks.from_hourly_ranges(@hourly_ranges)
    @aqi = Aqi.latest
    if @aqi.nil? || @aqi.stale? || @aqi.source != "airnow"
      DownloadAirNowAqiJob.perform_async
    end
    @wildfire = WildfireSnapshot.latest
    @aurora = AuroraSnapshot.latest
    @planet_night = ensure_planet_night
    @iss_pass = IssPass.next_visible || IssPass.next_any

    enqueue_sky_hazard_refreshes
  end

  def about
    @weather_measurement_count = WeatherMeasurement.count
    @first_weather_measurement = WeatherMeasurement.order(reading_date_time: :asc).first
  end

  private

  def ensure_planet_night
    night = PlanetNight.for_date(Time.zone.today)
    return night if night

    GeneratePlanetNightJob.perform_async(Time.zone.today.iso8601)
    nil
  end

  def enqueue_sky_hazard_refreshes
    if @wildfire.nil? || @wildfire.fetched_at < 30.minutes.ago
      DownloadNearestWildfireJob.perform_async
    end

    if @aurora.nil? || @aurora.fetched_at < 15.minutes.ago
      DownloadAuroraOutlookJob.perform_async
    end

    next_pass = IssPass.next_any
    if next_pass.nil? || next_pass.fetched_at < 6.hours.ago
      DownloadIssPassesJob.perform_async
    end
  end
end
