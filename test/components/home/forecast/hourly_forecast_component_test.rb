# frozen_string_literal: true

require "test_helper"

class Home::Forecast::HourlyForecastComponentTest < ViewComponent::TestCase
  # The template renders raw ForecastHour objects (as built by
  # ForecastParserService) so we construct them directly rather than
  # spinning up a fake Forecast fixture with hourly data.
  def build_hour(dt:, temp: 15.0, wind_speed: 4.0, wind_gust: 6.0, pop: 0.25, icon: "10d")
    ForecastParserService::ForecastHour.new(
      dt: dt,
      temp: temp,
      feels_like: temp,
      pressure: 1015,
      humidity: 60,
      wind_speed: wind_speed,
      wind_gust: wind_gust,
      wind_deg: 180,
      pop: pop,
      uvi: 0.5,
      clouds: 40,
      visibility: 10000,
      weather: [ { id: 500, main: "Rain", description: "light rain", icon: icon } ]
    )
  end

  setup do
    # Fixed timestamp so hour-of-day assertions are deterministic:
    # 10:00 AM Pacific = 18:00 UTC.
    @noon_pacific = Time.utc(2024, 6, 15, 19, 0, 0)   # 12:00 PM PDT
    @timestamp    = Time.utc(2024, 6, 15, 18, 30, 0)  # 11:30 AM PDT
    @hours = [
      build_hour(dt: @noon_pacific.to_i,               temp: 20.0, icon: "01d"),
      build_hour(dt: (@noon_pacific + 1.hour).to_i,    temp: 22.0, icon: "02d"),
      build_hour(dt: (@noon_pacific + 2.hours).to_i,   temp: 21.0, icon: "10d")
    ]
  end

  test "renders the hourly forecast container and heading" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp))

    assert_selector "div.hourly-forecast"
    assert_selector "h2.weather-tile-heading", text: "Hourly Forecast"
  end

  test "renders one entry per hour" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp))

    assert_selector "div.hourly-forecast-item", count: 3
  end

  test "renders the hour label with AM/PM in Pacific time" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp))

    assert_selector "p.hour", text: /12/
    assert_selector "p.hour span.ampm", text: "PM"
  end

  test "renders the rounded temperature with a degree symbol" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp))

    # Component consumes Celsius and displays Fahrenheit: 20°C → 68°F, 22°C → 72°F, 21°C → 70°F.
    assert_selector "p.temperature", text: "68°"
    assert_selector "p.temperature", text: "72°"
    assert_selector "p.temperature", text: "70°"
  end

  test "renders wind speed and gust rounded to whole numbers" do
    single_hour = [ build_hour(dt: @noon_pacific.to_i, wind_speed: 4.4704, wind_gust: 8.9408) ]

    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: single_hour, timestamp: @timestamp))

    # 4.4704 m/s -> 10 mph, 8.9408 m/s -> 20 mph
    assert_selector "p.wind", text: /10 \| 20/
    assert_selector "p.wind i.fa-wind"
  end

  test "renders precipitation as a percentage" do
    single_hour = [ build_hour(dt: @noon_pacific.to_i, pop: 0.35) ]

    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: single_hour, timestamp: @timestamp))

    assert_selector "p.precip", text: /35%/
    assert_selector "p.precip i.fa-cloud-rain"
  end

  test "renders the weather icon for each hour" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp))

    # Each hour gets an icon rendered via the shared partial
    assert_selector "div.icon-container", count: 3
    assert_selector "div.icon-container i", count: 3
  end

  test "renders the openweathermap attribution link with the formatted timestamp" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp))

    assert_text "as of"
    assert_selector "a[href='https://openweathermap.org/?utm_source=lhwx.org&utm_medium=referral'][target='_blank']",
                    text: "OpenWeatherMap"
  end

  test "handles being given no hours without crashing" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: [], timestamp: @timestamp))

    assert_selector "div.hourly-forecast"
    assert_no_selector "div.hourly-forecast-item"
  end

  test "coerces nil hours to an empty array" do
    render_inline(Home::Forecast::HourlyForecastComponent.new(hours: nil, timestamp: @timestamp))

    assert_selector "div.hourly-forecast"
    assert_no_selector "div.hourly-forecast-item"
  end

  test "exposes hours and timestamp as readers" do
    component = Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp)

    assert_equal @hours, component.hours
    assert_equal @timestamp, component.timestamp
  end

  test "formatted_timestamp formats in Pacific time with month/day/year and 12-hour clock" do
    component = Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp)

    assert_equal "Jun 15, 2024 @ 11:30 AM", component.formatted_timestamp
  end

  test "night_time? returns false when hour_time is nil" do
    component = Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp)

    assert_not component.night_time?(nil)
  end

  test "night_time? returns false when there's no almanac entry for that date" do
    component = Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp)

    # Fixture only has today's date; any date far away has no entry.
    assert_not component.night_time?(10.years.from_now)
  end

  test "night_time? returns true before sunrise and after sunset when an almanac entry exists" do
    # Build a fresh entry whose `date` is guaranteed to line up with the
    # `to_date` of the sunrise/sunset timestamps, regardless of the test
    # environment's system vs. Rails time zones.
    day = Date.new(2024, 6, 15)
    sunrise = Time.utc(2024, 6, 15, 13, 0, 0) # 06:00 PDT
    sunset  = Time.utc(2024, 6, 16, 4, 0, 0)  # 21:00 PDT (still same UTC date? 2024-06-16)
    # Ensure the entry's date matches both timestamps' to_date so find_by works.
    entry = AlmanacEntry.create!(
      date: sunrise.to_date,
      timezone: "America/Los_Angeles",
      sunrise_at: sunrise,
      sunset_at: sunrise + 8.hours # ensures sunset is on the same UTC date as sunrise
    )
    component = Home::Forecast::HourlyForecastComponent.new(hours: @hours, timestamp: @timestamp)

    before_sunrise = entry.sunrise_at - 1.hour
    after_sunset   = entry.sunset_at + 1.hour
    mid_day        = entry.sunrise_at + 3.hours

    assert component.night_time?(before_sunrise)
    assert component.night_time?(after_sunset)
    assert_not component.night_time?(mid_day)
  end
end
