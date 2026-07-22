# frozen_string_literal: true

require "test_helper"

class LibreWxrAlertsClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  setup do
    Rails.cache.clear
    @original_get = HTTParty.method(:get)
  end

  teardown do
    HTTParty.define_singleton_method(:get, @original_get)
  end

  test "returns empty list when lat or lon is missing" do
    assert_empty LibreWxrAlertsClient.new(lat: nil, lon: -122.2).fetch
    assert_empty LibreWxrAlertsClient.new(lat: 47.3, lon: nil).fetch
  end

  test "coordinates_from_env ignores blank and non-numeric values" do
    original_lat = ENV["LOCATION_LAT"]
    original_lon = ENV["LOCATION_LON"]
    begin
      ENV["LOCATION_LAT"] = ""
      ENV["LOCATION_LON"] = "-122.2"
      assert_equal [ nil, nil ], LibreWxrAlertsClient.coordinates_from_env

      ENV["LOCATION_LAT"] = "not-a-number"
      ENV["LOCATION_LON"] = "-122.2"
      assert_equal [ nil, nil ], LibreWxrAlertsClient.coordinates_from_env

      ENV["LOCATION_LAT"] = "47.307"
      ENV["LOCATION_LON"] = "-122.228"
      assert_equal [ 47.307, -122.228 ], LibreWxrAlertsClient.coordinates_from_env
    ensure
      ENV["LOCATION_LAT"] = original_lat
      ENV["LOCATION_LON"] = original_lon
    end
  end

  test "normalize_host strips metadata path suffixes like the radar client" do
    assert_equal(
      "https://api.librewxr.net",
      LibreWxrAlertsClient.normalize_host("https://api.librewxr.net/public/weather-maps.json")
    )
    assert_equal(
      "https://radar.example.com",
      LibreWxrAlertsClient.normalize_host("https://radar.example.com/")
    )
  end

  test "fetch uses normalized host when LIBREWXR_API_BASE includes metadata path" do
    captured_url = nil
    HTTParty.define_singleton_method(:get) do |url, **_kwargs|
      captured_url = url
      FakeResponse.new(code: 200, body: { "features" => [] }.to_json)
    end

    LibreWxrAlertsClient.new(
      lat: 47.3,
      lon: -122.2,
      host: "https://api.librewxr.net/public/weather-maps.json"
    ).fetch

    assert_equal "https://api.librewxr.net/v2/alerts?lat=47.3&lon=-122.2", captured_url
  end


  test "maps LibreWXR features into WeatherAlert objects" do
    payload = {
      "type" => "FeatureCollection",
      "features" => [
        {
          "type" => "Feature",
          "properties" => {
            "title" => "Dense Fog Advisory issued July 22 at 1:00AM PDT until July 22 at 9:00AM PDT by NWS",
            "description" => "Fog",
            "time" => 1.hour.ago.to_i,
            "expires" => 2.hours.from_now.to_i
          }
        }
      ]
    }
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: payload.to_json)
    end

    alerts = LibreWxrAlertsClient.new(lat: 47.307, lon: -122.228).fetch
    assert_equal 1, alerts.length
    assert_equal "Dense Fog Advisory", alerts.first.event
    assert_equal "Fog", alerts.first.description
  end

  test "returns empty list when the request fails" do
    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 500, body: "error")
    end

    assert_empty LibreWxrAlertsClient.new(lat: 47.307, lon: -122.228).fetch
  end
end
