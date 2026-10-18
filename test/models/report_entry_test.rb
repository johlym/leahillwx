# == Schema Information
#
# Table name: report_entries
#
#  id                 :bigint           not null, primary key
#  avg_wind_speed     :float
#  cool_degree_days   :float
#  day                :integer          not null
#  heat_degree_days   :float
#  high_pressure      :float
#  high_pressure_time :string
#  high_temp          :float
#  high_temp_time     :string
#  high_wind_speed    :float
#  high_wind_time     :string
#  hour               :integer
#  low_pressure       :float
#  low_pressure_time  :string
#  low_temp           :float
#  low_temp_time      :string
#  mean_pressure      :float
#  mean_temp          :float
#  partial_period     :boolean          default(FALSE), not null
#  rain               :float
#  wind_dir           :integer
#  wind_dir_compass   :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  report_id          :bigint           not null
#
# Indexes
#
#  index_report_entries_on_report_day_hour  (report_id,day,hour) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (report_id => reports.id) ON DELETE => cascade
#
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
    assert_equal "122.22", entry.formatted_temp(entry.mean_temp)
  end

  test "formatted_temp should return N/A for nil" do
    entry = @report.entries.create!(day: 1)
    assert_equal "N/A", entry.formatted_temp(nil)
  end

  test "partial_period should default to false" do
    entry = @report.entries.create!(day: 1)
    assert_equal false, entry.partial_period
  end

  test "should handle all formatting methods" do
    entry = @report.entries.create!(
      day: 1,
      rain: 3.048,  # mm (converts to ~0.12 inches)
      avg_wind_speed: 2.54,  # m/s (converts to ~5.68 mph)
      heat_degree_days: 10.999
    )

    assert_equal "0.12", entry.formatted_rain
    assert_equal "5.68", entry.formatted_wind_speed(entry.avg_wind_speed)
    assert_equal "11.00", entry.formatted_degree_days(entry.heat_degree_days)
  end
end
