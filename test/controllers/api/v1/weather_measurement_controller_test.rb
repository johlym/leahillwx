require "test_helper"

class Api::V1::WeatherMeasurementControllerTest < ActionDispatch::IntegrationTest
  test "should get create" do
    get api_v1_weather_measurement_create_url
    assert_response :success
  end
end
