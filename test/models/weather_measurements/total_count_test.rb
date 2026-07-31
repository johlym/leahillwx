# frozen_string_literal: true

require "test_helper"

class WeatherMeasurements::TotalCountTest < ActiveSupport::TestCase
  setup do
    WeatherMeasurements::TotalCount.clear!
  end

  teardown do
    WeatherMeasurements::TotalCount.clear!
  end

  test "read initializes from the database when redis key is missing" do
    expected = WeatherMeasurement.count

    assert_equal expected, WeatherMeasurements::TotalCount.read
    assert_equal expected, Sidekiq.redis { |redis|
      Integer(redis.get(WeatherMeasurements::TotalCount.redis_key))
    }
  end

  test "increment updates the cached count without recounting" do
    baseline = WeatherMeasurements::TotalCount.read

    assert_equal baseline + 3, WeatherMeasurements::TotalCount.increment!(by: 3)
    assert_equal baseline + 3, WeatherMeasurements::TotalCount.read
  end

  test "create callback increments the cached total count" do
    before = WeatherMeasurements::TotalCount.read

    create_measurement!(reading_date_time: Time.current)
    assert_equal before + 1, WeatherMeasurements::TotalCount.read

    create_measurement!(reading_date_time: 1.minute.from_now)
    assert_equal before + 2, WeatherMeasurements::TotalCount.read
  end

  test "recalculate replaces a stale redis value" do
    expected = WeatherMeasurement.count
    Sidekiq.redis do |redis|
      redis.set(WeatherMeasurements::TotalCount.redis_key, 999)
    end

    assert_equal expected, WeatherMeasurements::TotalCount.recalculate!
    assert_equal expected, WeatherMeasurements::TotalCount.read
  end


  private

  def create_measurement!(**attrs)
    WeatherMeasurement.create!(
      {
        reading_date_time: Time.current,
        barometer_abs: 1013.25,
        barometer_rel: 1013.25,
        gust_speed: 1.0,
        light: 100,
        humidity: 50,
        temperature: 20,
        rain_day: 0,
        rain_rate: 0,
        uv: 0,
        uvi: 0,
        wind_dir: 180,
        wind_speed: 1.0
      }.merge(attrs)
    )
  end
end
