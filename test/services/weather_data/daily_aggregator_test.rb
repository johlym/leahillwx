require "test_helper"

class WeatherData::DailyAggregatorTest < ActiveSupport::TestCase
  setup do
    @date = Date.parse("2024-01-15")
  end

  test "should initialize with date" do
    aggregator = WeatherData::DailyAggregator.new(@date)
    assert_equal @date, aggregator.date
  end

  test "should fetch measurements for given date" do
    aggregator = WeatherData::DailyAggregator.new(@date)
    assert_respond_to aggregator.measurements, :count
  end

  test "should create report and entry when aggregating" do
    aggregator = WeatherData::DailyAggregator.new(@date)

    assert_difference "Report.count", 1 do
      assert_difference "ReportEntry.count", 1 do
        entry = aggregator.aggregate
        assert_equal 15, entry.day
      end
    end
  end

  test "should not duplicate report if already exists" do
    Report.create!(year: @date.year, month: @date.month)
    aggregator = WeatherData::DailyAggregator.new(@date)

    assert_no_difference "Report.count" do
      aggregator.aggregate
    end
  end

  test "should update existing entry" do
    report = Report.create!(year: @date.year, month: @date.month)
    entry = report.entries.create!(day: 15, mean_temp: 40.0)

    aggregator = WeatherData::DailyAggregator.new(@date)

    assert_no_difference "ReportEntry.count" do
      updated_entry = aggregator.aggregate
      assert_equal entry.id, updated_entry.id
    end
  end

  test "should aggregate barometric pressure from measurements" do
    zone = ActiveSupport::TimeZone["America/Los_Angeles"]
    start_time = zone.local(@date.year, @date.month, @date.day, 10, 0, 0)

    WeatherMeasurement.create!(
      reading_date_time: start_time,
      barometer_abs: 1010.0,
      barometer_rel: 1012.0,
      gust_speed: 5.0,
      humidity: 60,
      light: 1000.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 20.0,
      uv: 3,
      uvi: 3.0,
      wind_dir: 180,
      wind_speed: 3.0
    )
    WeatherMeasurement.create!(
      reading_date_time: start_time + 1.hour,
      barometer_abs: 1015.0,
      barometer_rel: 1018.0,
      gust_speed: 6.0,
      humidity: 55,
      light: 1200.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 22.0,
      uv: 4,
      uvi: 4.0,
      wind_dir: 200,
      wind_speed: 4.0
    )
    WeatherMeasurement.create!(
      reading_date_time: start_time + 2.hours,
      barometer_abs: 1005.0,
      barometer_rel: 1008.0,
      gust_speed: 4.0,
      humidity: 65,
      light: 900.0,
      rain_day: 0.0,
      rain_rate: 0.0,
      temperature: 18.0,
      uv: 2,
      uvi: 2.0,
      wind_dir: 160,
      wind_speed: 2.0
    )

    entry = WeatherData::DailyAggregator.new(@date).aggregate

    assert_in_delta 1012.667, entry.mean_pressure, 0.01
    assert_equal 1018.0, entry.high_pressure
    assert_equal 1008.0, entry.low_pressure
    assert_equal "11:00", entry.high_pressure_time
    assert_equal "12:00", entry.low_pressure_time
  end
end
