# frozen_string_literal: true

require "test_helper"

class UpdateWeatherUndergroundJobTest < ActiveSupport::TestCase
  test "delegates to ThirdPartyWeather::WeatherUnderground" do
    original = ThirdPartyWeather::WeatherUnderground.method(:call)
    received = nil
    ThirdPartyWeather::WeatherUnderground.define_singleton_method(:call) do |id|
      received = id
    end

    UpdateWeatherUndergroundJob.new.perform(42)

    assert_equal 42, received
  ensure
    ThirdPartyWeather::WeatherUnderground.define_singleton_method(:call, original)
  end
end
