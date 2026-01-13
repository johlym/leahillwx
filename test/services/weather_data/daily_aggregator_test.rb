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
end
