# == Schema Information
#
# Table name: reports
#
#  id                        :bigint           not null, primary key
#  avg_wind_speed            :float
#  dominant_wind_dir         :integer
#  dominant_wind_dir_compass :string
#  month                     :integer          not null
#  month_high_temp           :float
#  month_high_temp_day       :integer
#  month_high_wind_day       :integer
#  month_high_wind_speed     :float
#  month_low_temp            :float
#  month_low_temp_day        :integer
#  month_mean_temp           :float
#  total_cool_degree_days    :float
#  total_heat_degree_days    :float
#  total_rain                :float
#  year                      :integer          not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#
# Indexes
#
#  index_reports_on_year_and_month  (year,month) UNIQUE
#
require "test_helper"

class ReportTest < ActiveSupport::TestCase
  test "should create valid report" do
    report = Report.new(year: 2024, month: 1)
    assert report.valid?
  end

  test "should require year and month" do
    report = Report.new
    assert_not report.valid?
    assert_includes report.errors[:year], "can't be blank"
    assert_includes report.errors[:month], "can't be blank"
  end

  test "should enforce unique year and month combination" do
    Report.create!(year: 2024, month: 1)
    report = Report.new(year: 2024, month: 1)
    assert_not report.valid?
    assert_includes report.errors[:year], "has already been taken"
  end

  test "should validate month range" do
    report = Report.new(year: 2024, month: 13)
    assert_not report.valid?

    report.month = 0
    assert_not report.valid?

    report.month = 6
    assert report.valid?
  end

  test "should return correct month_name" do
    report = Report.new(year: 2024, month: 1)
    assert_equal "January", report.month_name
  end

  test "should return correct display_name" do
    report = Report.new(year: 2024, month: 1)
    assert_equal "January 2024", report.display_name
  end

  test "should return correct days_in_month" do
    report = Report.new(year: 2024, month: 2) # Leap year
    assert_equal 29, report.days_in_month

    report = Report.new(year: 2023, month: 2) # Non-leap year
    assert_equal 28, report.days_in_month
  end

  test "should find report by month name" do
    report = Report.create!(year: 2024, month: 1)
    found = Report.find_by_month_name(2024, "january")
    assert_equal report.id, found.id
  end

  test "should cascade delete entries" do
    report = Report.create!(year: 2024, month: 1)
    report.entries.create!(day: 1, mean_temp: 50.0)
    report.entries.create!(day: 2, mean_temp: 55.0)

    assert_equal 2, report.entries.count
    report.destroy
    assert_equal 0, ReportEntry.where(report_id: report.id).count
  end
end
