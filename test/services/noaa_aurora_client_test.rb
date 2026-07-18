# frozen_string_literal: true

require "test_helper"

class NoaaAuroraClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true) do
    def success?
      code.to_i.between?(200, 299)
    end
  end

  setup do
    @original_get = HTTParty.method(:get)
  end

  teardown do
    HTTParty.define_singleton_method(:get, @original_get)
  end

  test "outlook parses kp ovation and labels" do
    kp_rows = [
      %w[time_tag kp],
      [ "2026-07-18 00:00:00.000", "2.33" ]
    ]
    forecast_rows = [
      %w[time_tag kp],
      [ (Time.zone.parse("2026-07-18 20:00:00") - 8.hours).utc.iso8601, "4.0" ]
    ]
    ovation = {
      "coordinates" => [
        [ 237.0, 47.0, 1.2 ],
        [ 238.0, 47.0, 12.5 ]
      ]
    }

    responses = {
      NoaaAuroraClient::KP_URL => kp_rows,
      NoaaAuroraClient::KP_FORECAST_URL => forecast_rows,
      NoaaAuroraClient::OVATION_URL => ovation
    }

    HTTParty.define_singleton_method(:get) do |url, **_kwargs|
      payload = responses.fetch(url)
      FakeResponse.new(code: 200, body: payload.to_json)
    end

    outlook = NoaaAuroraClient.new(lat: 47.3, lon: -122.2).outlook
    assert_in_delta 2.33, outlook[:kp], 0.01
    assert_equal "Quiet", outlook[:status_label]
    assert outlook[:local_ovation_pct]
    assert_match(/tonight|low|Possible|Elevated|unlikely/i, outlook[:odds_label])
  end
end
