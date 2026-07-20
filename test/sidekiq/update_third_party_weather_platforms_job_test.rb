# frozen_string_literal: true

require "test_helper"

class UpdateThirdPartyWeatherPlatformsJobTest < ActiveSupport::TestCase
  test "delegates to ThirdPartyWeather::EnqueueUpdates" do
    original = ThirdPartyWeather::EnqueueUpdates.method(:call)
    called = false
    ThirdPartyWeather::EnqueueUpdates.define_singleton_method(:call) { called = true }

    UpdateThirdPartyWeatherPlatformsJob.new.perform

    assert called
  ensure
    ThirdPartyWeather::EnqueueUpdates.define_singleton_method(:call, original)
  end
end
