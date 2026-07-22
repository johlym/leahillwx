# frozen_string_literal: true

require "test_helper"

class WeatherAlertTest < ActiveSupport::TestCase
  test "from_librewxr shortens issued titles and maps times" do
    feature = {
      "properties" => {
        "title" => "Heat Advisory issued July 22 at 3:12PM PDT until July 22 at 11:00PM PDT by NWS Seattle WA",
        "description" => "Hot conditions expected.",
        "time" => 1.hour.ago.to_i,
        "expires" => 2.hours.from_now.to_i
      }
    }

    alert = WeatherAlert.from_librewxr(feature)
    assert_equal "Heat Advisory", alert.event
    assert_equal "Hot conditions expected.", alert.description
    assert_equal "librewxr", alert.source
    assert alert.active?
    assert_equal alert.ends_at, alert.end_time
  end

  test "active? is false after expiry" do
    alert = WeatherAlert.new(
      event: "Heat Advisory",
      starts_at: 2.hours.ago,
      ends_at: 1.hour.ago
    )
    assert_not alert.active?
  end

  test "for_homepage merges LibreWXR and active OpenWeather alerts" do
    stub_librewxr_fetch([
      WeatherAlert.new(
        event: "Heat Advisory",
        description: "From LibreWXR",
        starts_at: 1.hour.ago,
        ends_at: 2.hours.from_now,
        source: "librewxr"
      )
    ]) do
      openweather = ForecastParser::ForecastAlert.new(
        sender_name: "NWS",
        event: "Air Quality Alert",
        start: 1.hour.ago.to_i,
        end: 3.hours.from_now.to_i,
        description: "Smoke",
        tags: []
      )
      expired = ForecastParser::ForecastAlert.new(
        sender_name: "NWS",
        event: "Wind Advisory",
        start: 2.days.ago.to_i,
        end: 1.day.ago.to_i,
        description: "Gone",
        tags: []
      )

      alerts = WeatherAlert.for_homepage(
        lat: 47.3,
        lon: -122.2,
        forecast_alerts: [ openweather, expired ]
      )

      assert_equal [ "Heat Advisory", "Air Quality Alert" ], alerts.map(&:event)
    end
  end

  test "for_homepage dedupes matching event names" do
    stub_librewxr_fetch([
      WeatherAlert.new(
        event: "Heat Advisory",
        starts_at: 1.hour.ago,
        ends_at: 2.hours.from_now,
        source: "librewxr"
      )
    ]) do
      openweather = ForecastParser::ForecastAlert.new(
        sender_name: "NWS",
        event: "Heat Advisory",
        start: 1.hour.ago.to_i,
        end: 2.hours.from_now.to_i,
        description: "Duplicate",
        tags: []
      )

      alerts = WeatherAlert.for_homepage(
        lat: 47.3,
        lon: -122.2,
        forecast_alerts: [ openweather ]
      )

      assert_equal [ "Heat Advisory" ], alerts.map(&:event)
      assert_equal "librewxr", alerts.first.source
    end
  end

  private

  def stub_librewxr_fetch(alerts)
    fake = Object.new
    fake.define_singleton_method(:fetch) { alerts }

    LibreWxrAlertsClient.singleton_class.alias_method(:__orig_new, :new)
    LibreWxrAlertsClient.define_singleton_method(:new) { |*_args, **_kwargs| fake }
    yield
  ensure
    LibreWxrAlertsClient.singleton_class.remove_method(:new)
    LibreWxrAlertsClient.singleton_class.alias_method(:new, :__orig_new)
    LibreWxrAlertsClient.singleton_class.remove_method(:__orig_new)
  end
end
