# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SoilComponentTest < ViewComponent::TestCase
  test "renders compact soil sensor rows with moisture and optional temp" do
    readings = [
      {
        "channel" => 1,
        "name" => "Raised bed",
        "moisture" => 78,
        "moisture_battery" => 1.6,
        "temperature_f" => 50,
        "temperature_battery" => 1.55
      },
      { "channel" => 2, "name" => "Ch 2", "moisture" => 55 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_text "Soil Sensors"
    assert_text "Raised bed"
    assert_text "78%"
    assert_text "/ 50°F"
    assert_text "Ch 2"
    assert_text "55%"
    assert_no_text "1.60"
    assert_no_text "Batt."
    assert_selector ".ui-card.soil-card"
    assert_selector "[data-weather-update-target='soil']"
    assert_selector ".soil-channel", count: 2
  end

  test "omits battery and temp dash placeholders in compact layout" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78, "temperature_f" => 50 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_text "78%"
    assert_text "/ 50°F"
    assert_no_text "—"
    assert_no_selector ".soil-channel-battery-number"
  end

  test "renders empty state when no sensors" do
    render_inline(Home::CurrentWeather::SoilComponent.new(readings: []))

    assert_text "Soil Sensors"
    assert_text "No sensors reporting"
  end
end
