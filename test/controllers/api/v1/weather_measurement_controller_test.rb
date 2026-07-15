require "test_helper"

class Api::V1::WeatherMeasurementControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_key = "test-measurement-key"
    ENV["MEASUREMENT_API_KEY"] = @api_key
  end

  teardown do
    ENV.delete("MEASUREMENT_API_KEY")
  end

  def auth_headers
    { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
  end

  def measurement_payload(overrides = {})
    {
      weather_measurement: {
        reading_date_time: Time.current.iso8601,
        barometer_abs: 1013.2,
        barometer_rel: 1015.0,
        gust_speed: 2.5,
        light: 1200.0,
        humidity: 65,
        temperature: 18.5,
        rain_day: 0.0,
        rain_rate: 0.0,
        uv: 3,
        uvi: 3.0,
        wind_dir: 180,
        wind_speed: 1.2
      }.merge(overrides)
    }
  end

  test "create stores soil channels" do
    payload = measurement_payload(
      soil: [ { channel: 1, moisture: 78.0, battery: 1.6 } ]
    )

    assert_difference("WeatherMeasurement.count", 1) do
      post api_v1_weather_measurement_url, params: payload, headers: auth_headers, as: :json
    end

    assert_response :no_content

    measurement = WeatherMeasurement.order(:id).last
    assert_equal [ { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 } ], measurement.soil
  end

  test "create succeeds without soil" do
    assert_difference("WeatherMeasurement.count", 1) do
      post api_v1_weather_measurement_url, params: measurement_payload, headers: auth_headers, as: :json
    end

    assert_response :no_content
    assert_equal [], WeatherMeasurement.order(:id).last.soil
  end

  test "create rejects invalid soil channel" do
    payload = measurement_payload(
      soil: [ { channel: 9, moisture: 78.0, battery: 1.6 } ]
    )

    assert_no_difference("WeatherMeasurement.count") do
      post api_v1_weather_measurement_url, params: payload, headers: auth_headers, as: :json
    end

    assert_response :unprocessable_entity
  end
end
