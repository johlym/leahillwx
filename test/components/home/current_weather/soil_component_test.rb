# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SoilComponentTest < ViewComponent::TestCase
  test "renders soil table headers and channel values" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78, "temperature_f" => 50, "battery" => 1.6 },
      { "channel" => 2, "name" => "Ch 2", "moisture" => 55 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_text "Soil"
    assert_text "Sensor"
    assert_text "Humidity"
    assert_text "Temp."
    assert_text "Batt."
    assert_text "Raised bed"
    assert_text "78"
    assert_text "50"
    assert_text "1.60"
    assert_text "V"
    assert_text "Ch 2"
    assert_text "55"
    assert_text "N/A"
    assert_selector ".ui-card.soil-card"
    assert_selector ".soil-table-header"
    assert_selector "[data-weather-update-target='soil']"
    assert_selector ".soil-channel-battery-number"
  end

  test "renders N/A for missing battery voltage" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_text "N/A"
    assert_no_selector ".soil-channel-battery-number"
  end

  test "renders empty state when no sensors" do
    render_inline(Home::CurrentWeather::SoilComponent.new(readings: []))

    assert_text "Sensor"
    assert_text "Batt."
    assert_text "No sensors reporting"
  end
end
