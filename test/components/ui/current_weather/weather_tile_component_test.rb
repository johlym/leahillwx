# frozen_string_literal: true

require "test_helper"

class Ui::CurrentWeather::WeatherTileComponentTest < ViewComponent::TestCase
  def test_renders_temperature_tile_with_heading
    measurement = weather_measurements(:one)
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "current-temperature",
      heading: "Current Temperature",
      measurement: measurement,
      counter: 42
    )

    render_inline(component)

    assert_selector "div.weather-tile.current-temperature"
    assert_selector "h2.weather-tile-heading", text: "Current Temperature"
    assert_selector "span.current-temperature-f"
    assert_selector "span.current-temperature-c"
    assert_selector "span.measurement-id", text: /No\. 42/
  end

  def test_renders_temperature_tile_without_heading
    measurement = weather_measurements(:one)
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "current-temperature",
      measurement: measurement,
      counter: 100
    )

    render_inline(component)

    assert_selector "div.weather-tile.current-temperature"
    assert_no_selector "h2.weather-tile-heading"
    assert_selector "span.measurement-id", text: /No\. 100/
  end

  def test_formats_temperature_correctly
    measurement = weather_measurements(:one)
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "current-temperature",
      measurement: measurement,
      counter: 1
    )

    render_inline(component)

    expected_temp = measurement.temperature.to_fahrenheit
    assert_selector "span.current-temperature-f", text: /#{expected_temp}/
  end

  def test_formats_feels_like_correctly
    measurement = weather_measurements(:one)
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "current-temperature",
      measurement: measurement,
      counter: 1
    )

    render_inline(component)

    expected_feels_like = measurement.feels_like.to_fahrenheit
    assert_selector "span.current-temperature-c", text: /feels like #{expected_feels_like}/
  end

  def test_renders_generic_tile_with_primary_value_only
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "humidity",
      heading: "Humidity"
    )

    render_inline(component) do |c|
      c.with_primary_value { "65%" }
    end

    assert_selector "div.weather-tile.humidity"
    assert_selector "h2.weather-tile-heading", text: "Humidity"
    assert_selector "span.weather-tile-big", text: "65%"
    assert_no_selector "span.weather-tile-small"
  end

  def test_renders_generic_tile_with_primary_and_secondary_values
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "wind",
      heading: "Wind Speed"
    )

    render_inline(component) do |c|
      c.with_primary_value { "12 mph" }
      c.with_secondary_value { "N" }
    end

    assert_selector "div.weather-tile.wind"
    assert_selector "h2.weather-tile-heading", text: "Wind Speed"
    assert_selector "span.weather-tile-big", text: "12 mph"
    assert_selector "span.weather-tile-small", text: "N"
  end

  def test_renders_generic_tile_without_heading
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "pressure"
    )

    render_inline(component) do |c|
      c.with_primary_value { "30.12 inHg" }
    end

    assert_selector "div.weather-tile.pressure"
    assert_no_selector "h2.weather-tile-heading"
    assert_selector "span.weather-tile-big", text: "30.12 inHg"
  end

  def test_counter_formatted_with_delimiter
    measurement = weather_measurements(:one)
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "current-temperature",
      measurement: measurement,
      counter: 1234567
    )

    render_inline(component)

    assert_selector "span.measurement-id", text: /No\. 1,234,567/
  end

  def test_heading_predicate_returns_true_when_heading_present
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "test",
      heading: "Test Heading"
    )

    assert component.heading?
  end

  def test_heading_predicate_returns_false_when_heading_blank
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "test"
    )

    refute component.heading?
  end

  def test_temperature_predicate_returns_true_for_current_temperature_type
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "current-temperature"
    )

    assert component.temperature?
  end

  def test_temperature_predicate_returns_false_for_other_types
    component = Ui::CurrentWeather::WeatherTileComponent.new(
      tile_type: "humidity"
    )

    refute component.temperature?
  end
end
