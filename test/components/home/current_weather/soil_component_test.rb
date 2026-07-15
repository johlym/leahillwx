# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::SoilComponentTest < ViewComponent::TestCase
  test "renders soil channel moisture and temperature" do
    readings = [
      { "channel" => 1, "name" => "Raised bed", "moisture" => 78, "temperature_f" => 50 },
      { "channel" => 2, "name" => "Ch 2", "moisture" => 55 }
    ]

    render_inline(Home::CurrentWeather::SoilComponent.new(readings: readings))

    assert_text "Soil"
    assert_text "Raised bed"
    assert_text "78"
    assert_text "50"
    assert_text "Ch 2"
    assert_text "55"
    assert_selector ".ui-card.lg\\:row-span-2"
    assert_selector "[data-weather-update-target='soil']"
  end


  test "renders empty state when no sensors" do
    render_inline(Home::CurrentWeather::SoilComponent.new(readings: []))

    assert_text "No sensors reporting"
  end
end
