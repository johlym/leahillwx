# frozen_string_literal: true

require "test_helper"

class Home::Forecast::AlertsBarComponentTest < ViewComponent::TestCase
  test "does not render when there are no active alerts" do
    alert = ForecastParser::ForecastAlert.new(
      sender_name: "NWS",
      event: "Heat Advisory",
      start: 1.day.ago.to_i,
      end: 1.hour.ago.to_i,
      description: "Expired",
      tags: []
    )

    render_inline(Home::Forecast::AlertsBarComponent.new(alerts: [ alert ]))
    assert_no_text "Heat Advisory"
  end

  test "renders compact bar with indicator, title, and expiry linking to alerts" do
    alert = ForecastParser::ForecastAlert.new(
      sender_name: "NWS Seattle",
      event: "Heat Advisory",
      start: 1.hour.ago.to_i,
      end: 2.hours.from_now.to_i,
      description: "Hot conditions expected across the lowlands.",
      tags: [ "Heat" ]
    )

    render_inline(Home::Forecast::AlertsBarComponent.new(alerts: [ alert ]))
    assert_text "Alert"
    assert_text "Heat Advisory"
    assert_text(/Until/i)
    assert_no_text "Hot conditions expected"
    assert_selector "a.forecast-alerts-bar[href='/alerts'][data-turbo-frame='_top']"
  end

  test "shows alert count in indicator when multiple are active" do
    alerts = [
      ForecastParser::ForecastAlert.new(
        sender_name: "NWS",
        event: "Heat Advisory",
        start: 1.hour.ago.to_i,
        end: 2.hours.from_now.to_i,
        description: "Hot",
        tags: []
      ),
      ForecastParser::ForecastAlert.new(
        sender_name: "NWS",
        event: "Air Quality Alert",
        start: 1.hour.ago.to_i,
        end: 3.hours.from_now.to_i,
        description: "Smoke",
        tags: []
      )
    ]

    render_inline(Home::Forecast::AlertsBarComponent.new(alerts: alerts))
    assert_text "2 Alerts"
    assert_text "Heat Advisory"
    assert_no_text "+1 more"
  end
end
