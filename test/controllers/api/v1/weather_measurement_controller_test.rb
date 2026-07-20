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

  test "create rejects request when MEASUREMENT_API_KEY is blank" do
    ENV.delete("MEASUREMENT_API_KEY")

    assert_no_difference("WeatherMeasurement.count") do
      post api_v1_weather_measurement_url,
           params: measurement_payload,
           headers: { "Authorization" => "Bearer ", "Content-Type" => "application/json" },
           as: :json
    end

    assert_response :unauthorized
  end

  test "create rejects request with wrong api key" do
    assert_no_difference("WeatherMeasurement.count") do
      post api_v1_weather_measurement_url,
           params: measurement_payload,
           headers: { "Authorization" => "Bearer wrong-key", "Content-Type" => "application/json" },
           as: :json
    end

    assert_response :unauthorized
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

  test "create stores temp_probes" do
    payload = measurement_payload(
      soil: [ { channel: 1, moisture: 78.0, battery: 1.6 } ],
      temp_probes: [ { channel: 2, temperature: 10.0, battery: 1.55 } ]
    )

    assert_difference("WeatherMeasurement.count", 1) do
      post api_v1_weather_measurement_url, params: payload, headers: auth_headers, as: :json
    end

    assert_response :no_content

    measurement = WeatherMeasurement.order(:id).last
    assert_equal [ { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 } ], measurement.soil
    assert_equal [ { "channel" => 2, "temperature" => 10.0, "battery" => 1.55 } ], measurement.temp_probes
  end

  test "create succeeds without soil or temp_probes" do
    assert_difference("WeatherMeasurement.count", 1) do
      post api_v1_weather_measurement_url, params: measurement_payload, headers: auth_headers, as: :json
    end

    assert_response :no_content
    measurement = WeatherMeasurement.order(:id).last
    assert_equal [], measurement.soil
    assert_equal [], measurement.temp_probes
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

  test "create rejects invalid temp_probe channel" do
    payload = measurement_payload(
      temp_probes: [ { channel: 9, temperature: 10.0, battery: 1.55 } ]
    )

    assert_no_difference("WeatherMeasurement.count") do
      post api_v1_weather_measurement_url, params: payload, headers: auth_headers, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create rejects temp_probe without temperature" do
    payload = measurement_payload(
      temp_probes: [ { channel: 1, battery: 1.55 } ]
    )

    assert_no_difference("WeatherMeasurement.count") do
      post api_v1_weather_measurement_url, params: payload, headers: auth_headers, as: :json
    end

    assert_response :unprocessable_entity
  end

  test "create treats duplicate reading_date_time as success" do
    reading_at = Time.zone.parse("2026-06-01 12:00:00")
    WeatherMeasurement.create!(
      reading_date_time: reading_at,
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
    )

    assert_no_difference("WeatherMeasurement.count") do
      post api_v1_weather_measurement_url,
           params: measurement_payload(reading_date_time: reading_at.iso8601),
           headers: auth_headers,
           as: :json
    end

    assert_response :no_content
  end
end
