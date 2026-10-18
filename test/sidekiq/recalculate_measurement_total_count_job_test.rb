# frozen_string_literal: true

require "test_helper"

class RecalculateMeasurementTotalCountJobTest < ActiveSupport::TestCase
  test "replaces a drifted redis counter from the table" do
    expected = WeatherMeasurement.count
    Sidekiq.redis do |redis|
      redis.set(WeatherMeasurements::TotalCount.redis_key, 999)
    end

    RecalculateMeasurementTotalCountJob.new.perform

    assert_equal expected, WeatherMeasurements::TotalCount.read
  end
end
