# frozen_string_literal: true

require "test_helper"

class WaDnrWildfireClientTest < ActiveSupport::TestCase
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

  test "queries only uncontrolled wildfire-class incidents" do
    captured = nil
    HTTParty.define_singleton_method(:get) do |_url, **kwargs|
      captured = kwargs[:query]
      FakeResponse.new(code: 200, body: { "features" => [] }.to_json)
    end

    WaDnrWildfireClient.new.active_fires

    assert_includes captured[:where], "FIRE_OUT_DT IS NULL"
    assert_includes captured[:where], "CONTROL_DT IS NULL"
    assert_includes captured[:where], "FIREEVNT_CLASS_LABEL_NM = 'WF'"
  end

  test "normalizes live fire features" do
    payload = {
      "features" => [
        {
          "attributes" => {
            "INCIDENT_NM" => "Brown Weiler",
            "ACRES_BURNED" => 3.0,
            "LAT_COORD" => 47.4,
            "LON_COORD" => -122.1,
            "FIREEVENT_ID" => 99,
            "FIREEVNT_CLASS_LABEL_NM" => "WF"
          },
          "geometry" => { "x" => -122.1, "y" => 47.4 }
        }
      ]
    }

    HTTParty.define_singleton_method(:get) do |*_args, **_kwargs|
      FakeResponse.new(code: 200, body: payload.to_json)
    end

    fires = WaDnrWildfireClient.new.active_fires
    assert_equal 1, fires.size
    assert_equal "Brown Weiler", fires.first[:name]
    assert_equal 3.0, fires.first[:acres]
    assert_equal "wadnr", fires.first[:source]
  end
end
