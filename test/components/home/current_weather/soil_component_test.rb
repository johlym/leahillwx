# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SoilComponentTest < ViewComponent::TestCase
  test "renders soil table headers and channel values" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78, "temperature_f" => 50, "battery" => 5 },
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
    assert_text "Ch 2"
    assert_text "55"
    assert_text "N/A"
    assert_selector ".ui-card.soil-card"
    assert_selector ".soil-table-header"
    assert_selector "[data-weather-update-target='soil']"
    assert_selector ".fa-battery-full"
    assert_selector ".soil-channel-battery", count: 2
  end

  test "renders battery-low icon for level 3" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78, "battery" => 3 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_selector ".fa-battery-low"
    assert_no_selector ".soil-battery-critical"
  end

  test "renders pulsing exclamation icon for levels 1 and 2" do
    readings = [
      { "channel" => 1, "name" => "Low bed", "moisture" => 40, "battery" => 2 },
      { "channel" => 2, "name" => "Critical bed", "moisture" => 35, "battery" => 1 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_selector ".fa-battery-exclamation.soil-battery-critical", count: 2
  end

  test "renders empty battery cell when battery is missing" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_selector ".soil-channel-battery", count: 1
    assert_no_selector ".soil-channel-battery i"
  end

  test "renders empty state when no sensors" do
    render_inline(Home::CurrentWeather::SoilComponent.new(readings: []))

    assert_text "Sensor"
    assert_text "Batt."
    assert_text "No sensors reporting"
  end
end
