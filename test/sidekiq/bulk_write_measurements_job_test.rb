require "test_helper"

class BulkWriteMeasurementsJobTest < ActiveSupport::TestCase
  def measurement_hash(overrides = {})
    {
      "reading_date_time" => Time.current.change(usec: 0).iso8601,
      "barometer_abs" => 1013.2,
      "barometer_rel" => 1015.0,
      "gust_speed" => 2.5,
      "light" => 1200.0,
      "humidity" => 65,
      "temperature" => 18.5,
      "rain_day" => 0.0,
      "rain_rate" => 0.0,
      "uv" => 3,
      "uvi" => 3.0,
      "wind_dir" => 180,
      "wind_speed" => 1.2,
      "soil" => [],
      "temp_probes" => []
    }.merge(overrides)
  end

  test "inserts new measurements by default" do
    payload = [ measurement_hash ]

    assert_difference("WeatherMeasurement.count", 1) do
      BulkWriteMeasurementsJob.new.perform(payload)
    end
  end

  test "persists soil and temp_probes on bulk insert" do
    payload = [
      measurement_hash(
        "soil" => [ { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 } ],
        "temp_probes" => [ { "channel" => 2, "temperature" => 10.0, "battery" => 1.55 } ]
      )
    ]

    assert_difference("WeatherMeasurement.count", 1) do
      BulkWriteMeasurementsJob.new.perform(payload)
    end

    measurement = WeatherMeasurement.order(:id).last
    assert_equal [ { "channel" => 1, "moisture" => 78.0, "battery" => 1.6 } ], measurement.soil
    assert_equal [ { "channel" => 2, "temperature" => 10.0, "battery" => 1.55 } ], measurement.temp_probes
  end

  test "skips duplicate timestamps by default" do
    reading_at = Time.zone.parse("2026-03-01 12:00:00")
    WeatherMeasurement.create!(measurement_hash("reading_date_time" => reading_at).symbolize_keys)

    payload = [ measurement_hash("reading_date_time" => reading_at.iso8601, "temperature" => 99.0) ]

    assert_no_difference("WeatherMeasurement.count") do
      BulkWriteMeasurementsJob.new.perform(payload)
    end

    assert_equal 18.5, WeatherMeasurement.find_by!(reading_date_time: reading_at).temperature
  end

  test "update_records updates existing and inserts new" do
    existing_at = Time.zone.parse("2026-03-01 12:00:00")
    new_at = Time.zone.parse("2026-03-01 12:01:00")
    WeatherMeasurement.create!(measurement_hash("reading_date_time" => existing_at).symbolize_keys)

    payload = [
      measurement_hash("reading_date_time" => existing_at.iso8601, "temperature" => 22.0),
      measurement_hash("reading_date_time" => new_at.iso8601, "temperature" => 23.0)
    ]

    assert_difference("WeatherMeasurement.count", 1) do
      BulkWriteMeasurementsJob.new.perform(payload, true, false)
    end

    assert_equal 22.0, WeatherMeasurement.find_by!(reading_date_time: existing_at).temperature
    assert_equal 23.0, WeatherMeasurement.find_by!(reading_date_time: new_at).temperature
  end

  test "overwrite replaces existing timestamps" do
    reading_at = Time.zone.parse("2026-03-01 12:00:00")
    WeatherMeasurement.create!(measurement_hash("reading_date_time" => reading_at).symbolize_keys)

    payload = [ measurement_hash("reading_date_time" => reading_at.iso8601, "temperature" => 30.0) ]

    assert_no_difference("WeatherMeasurement.count") do
      BulkWriteMeasurementsJob.new.perform(payload, false, true)
    end

    assert_equal 30.0, WeatherMeasurement.find_by!(reading_date_time: reading_at).temperature
  end

  test "re-raises after logging so Sidekiq can retry" do
    payload = [ measurement_hash ]
    job = BulkWriteMeasurementsJob.new
    original = WeatherMeasurement.method(:insert_all!)

    WeatherMeasurement.define_singleton_method(:insert_all!) do |*|
      raise StandardError, "db down"
    end

    error = assert_raises(StandardError) { job.perform(payload) }
    assert_equal "db down", error.message
  ensure
    WeatherMeasurement.define_singleton_method(:insert_all!, original) if original
  end
end
