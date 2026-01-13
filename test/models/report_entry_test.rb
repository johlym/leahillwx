require "test_helper"

class ReportEntryTest < ActiveSupport::TestCase
  setup do
    @report = Report.create!(year: 2024, month: 1)
  end

  test "should create valid entry" do
    entry = @report.entries.new(day: 15, mean_temp: 50.0)
    assert entry.valid?
  end

  test "should require day" do
    entry = @report.entries.new(mean_temp: 50.0)
    assert_not entry.valid?
    assert_includes entry.errors[:day], "can't be blank"
  end

  test "should validate day range" do
    entry = @report.entries.new(day: 0)
    assert_not entry.valid?

    entry.day = 32
    assert_not entry.valid?

    entry.day = 15
    assert entry.valid?
  end

  test "should enforce unique day per report" do
    @report.entries.create!(day: 15, mean_temp: 50.0)
    entry = @report.entries.new(day: 15)
    assert_not entry.valid?
    assert_includes entry.errors[:day], "has already been taken"
  end

  test "has_data? should return true when data present" do
    entry = @report.entries.create!(day: 1, mean_temp: 50.0)
    assert entry.has_data?
  end

  test "has_data? should return false when no data" do
    entry = @report.entries.create!(day: 1)
    assert_not entry.has_data?
  end

  test "formatted_temp should format with 2 decimals" do
    entry = @report.entries.create!(day: 1, mean_temp: 50.123)
    assert_equal "50.12", entry.formatted_temp(entry.mean_temp)
  end

  test "formatted_temp should return N/A for nil" do
    entry = @report.entries.create!(day: 1)
    assert_equal "N/A", entry.formatted_temp(nil)
  end

  test "partial_day should default to false" do
    entry = @report.entries.create!(day: 1)
    assert_equal false, entry.partial_day
  end

  test "should handle all formatting methods" do
    entry = @report.entries.create!(
      day: 1,
      rain: 0.123,
      avg_wind_speed: 5.678,
      heat_degree_days: 10.999
    )

    assert_equal "0.12", entry.formatted_rain
    assert_equal "5.68", entry.formatted_wind_speed(entry.avg_wind_speed)
    assert_equal "11.00", entry.formatted_degree_days(entry.heat_degree_days)
  end
end
