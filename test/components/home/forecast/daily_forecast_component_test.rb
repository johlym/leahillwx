# frozen_string_literal: true

require "test_helper"

class Home::Forecast::DailyForecastComponentTest < ViewComponent::TestCase
  def setup
    @forecast_record = forecasts(:one)
    @parsed_forecast = ForecastParser.new(@forecast_record).parse
  end

  def test_renders_forecast_grid_container
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    assert_selector "div.weather-tile.weekly-forecast"
  end

  def test_renders_heading
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    assert_selector "h2.weather-tile-heading", text: "7-Day Forecast"
  end

  def test_formatted_timestamp_includes_date_and_time
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    timestamp = component.formatted_timestamp

    assert_match(/\w+ \d+, \d{4} @ \d{2}:\d{2}/, timestamp)
  end

  def test_renders_forecast_entries_for_each_day
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    assert_selector "div.forecast-entry", count: @parsed_forecast.days.count
  end

  def test_renders_day_name_and_date
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    first_day = @parsed_forecast.days.first
    assert_selector "p.dayname", text: first_day.date.strftime("%a")
    assert_selector "p.daynum", text: /#{first_day.date.strftime("%b")} #{first_day.date.strftime("%-d")}/
  end

  def test_renders_temperature_high_and_low
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    first_day = @parsed_forecast.days.first
    assert_selector "div.forecast-temps span.high", text: "#{first_day.temp_max.round}°"
    assert_selector "div.forecast-temps span.low", text: "#{first_day.temp_min.round}°"
  end

  def test_renders_weather_description
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    first_day = @parsed_forecast.days.first
    assert_selector "span.forecast-condition-label", text: first_day.weather_description&.titleize
  end

  def test_renders_forecast_summary
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    first_day = @parsed_forecast.days.first
    assert_selector "p.forecast-summary", text: /#{first_day.summary}/
  end

  def test_renders_date_grid_section
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    assert_selector "div.date-grid"
  end

  def test_renders_conditions_section
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    assert_selector "div.conditions"
    assert_selector "div.icon"
    assert_selector "div.forecast-temps"
  end

  def test_renders_forecast_text_section
    component = Home::Forecast::DailyForecastComponent.new(days: @parsed_forecast.days, timestamp: @forecast_record.created_at)

    render_inline(component)

    assert_selector "div.forecast-text"
  end
end
