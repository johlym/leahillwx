# frozen_string_literal: true

require "test_helper"

class AlertsControllerTest < ActionDispatch::IntegrationTest
  test "index renders full alert details" do
    stub_librewxr_alerts([
      WeatherAlert.new(
        event: "Heat Advisory",
        title: "Heat Advisory issued July 22 at 3:12PM PDT until July 22 at 11:00PM PDT by NWS Seattle WA",
        description: "* WHAT...Hot conditions with high temperatures.\n\n* IMPACTS...Heat illness risk.",
        starts_at: 1.hour.ago,
        ends_at: 2.hours.from_now,
        source: "librewxr",
        severity: "Moderate",
        regions: [ "City of Seattle; Eastside" ],
        uri: "urn:oid:example"
      )
    ]) do
      get alerts_url
      assert_response :success
      assert_select "h2", text: /Heat Advisory issued July 22/
      assert_select ".alerts-page-body", text: /IMPACTS/
      assert_select ".alerts-page-regions", text: /City of Seattle/
      assert_select ".alerts-page-severity", text: /Moderate/
      assert_select ".alerts-page-source", text: /LibreWXR/
    end
  end

  test "index shows empty state when there are no alerts" do
    stub_librewxr_alerts([]) do
      get alerts_url
      assert_response :success
      assert_select ".alerts-page-empty", text: /No active weather alerts/
    end
  end

  test "bar renders alert bar inside turbo frame when alerts are present" do
    stub_librewxr_alerts([
      WeatherAlert.new(
        event: "Heat Advisory",
        description: "Hot conditions expected across the lowlands.",
        starts_at: 1.hour.ago,
        ends_at: 2.hours.from_now,
        source: "librewxr"
      )
    ]) do
      get alerts_bar_url
      assert_response :success
      assert_select "turbo-frame#weather_alerts_bar a.forecast-alerts-bar[href='#{alerts_path}']", text: /Heat Advisory/
      assert_select "turbo-frame#weather_alerts_bar a.forecast-alerts-bar", text: /Until/
      assert_select "a.forecast-alerts-bar", text: /Hot conditions/, count: 0
      assert_select "header.site-header", count: 0
    end
  end

  test "bar returns empty turbo frame when there are no alerts" do
    stub_librewxr_alerts([]) do
      get alerts_bar_url
      assert_response :success
      assert_select "turbo-frame#weather_alerts_bar"
      assert_select "a.forecast-alerts-bar", count: 0
    end
  end

  private

  def stub_librewxr_alerts(alerts)
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
