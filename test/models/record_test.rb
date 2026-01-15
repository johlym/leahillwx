# frozen_string_literal: true

# == Schema Information
#
# Table name: records
#
#  id                          :bigint           not null, primary key
#  consecutive_dry_days        :integer
#  consecutive_dry_start_date  :date
#  consecutive_rain_days       :integer
#  consecutive_rain_start_date :date
#  highest_apparent_temp       :float
#  highest_apparent_temp_at    :datetime
#  highest_daily_rain          :float
#  highest_daily_rain_date     :date
#  highest_dew_point           :float
#  highest_dew_point_at        :datetime
#  highest_heat_index          :float
#  highest_heat_index_at       :datetime
#  highest_humidity            :integer
#  highest_humidity_at         :datetime
#  highest_pressure            :float
#  highest_pressure_at         :datetime
#  highest_rain_rate           :float
#  highest_rain_rate_at        :datetime
#  highest_solar               :float
#  highest_solar_at            :datetime
#  highest_temp                :float
#  highest_temp_at             :datetime
#  highest_wind_run            :float
#  highest_wind_run_date       :date
#  largest_pressure_swing      :float
#  largest_pressure_swing_date :date
#  largest_temp_range          :float
#  largest_temp_range_date     :date
#  longest_calm_hours          :integer
#  longest_calm_start_at       :datetime
#  lowest_apparent_temp        :float
#  lowest_apparent_temp_at     :datetime
#  lowest_dew_point            :float
#  lowest_dew_point_at         :datetime
#  lowest_humidity             :integer
#  lowest_humidity_at          :datetime
#  lowest_pressure             :float
#  lowest_pressure_at          :datetime
#  lowest_temp                 :float
#  lowest_temp_at              :datetime
#  lowest_wind_chill           :float
#  lowest_wind_chill_at        :datetime
#  scope                       :string           not null
#  smallest_temp_range         :float
#  smallest_temp_range_date    :date
#  strongest_gust              :float
#  strongest_gust_at           :datetime
#  wettest_month               :integer
#  wettest_month_total         :float
#  wettest_month_year          :integer
#  year                        :integer
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#
# Indexes
#
#  index_records_on_scope_and_year  (scope,year) UNIQUE
#
require "test_helper"

class RecordTest < ActiveSupport::TestCase
  test "yearly scope requires year" do
    record = Record.new(scope: "yearly")
    assert_not record.valid?
    assert_includes record.errors[:year], "can't be blank"
  end

  test "yearly scope validates successfully with year" do
    record = Record.new(scope: "yearly", year: 2024)
    assert record.valid?
  end

  test "all_time scope requires no year" do
    record = Record.new(scope: "all_time", year: 2024)
    assert_not record.valid?
    assert_includes record.errors[:year], "must be blank"
  end

  test "all_time scope validates successfully without year" do
    record = Record.new(scope: "all_time")
    assert record.valid?
  end

  test "scope must be unique for year combination" do
    Record.create!(scope: "yearly", year: 2024)
    duplicate = Record.new(scope: "yearly", year: 2024)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:scope], "has already been taken"
  end

  test "for_year scope returns records for specific year" do
    record_2023 = Record.create!(scope: "yearly", year: 2023)
    record_2024 = Record.create!(scope: "yearly", year: 2024)

    results = Record.for_year(2024)
    assert_includes results, record_2024
    assert_not_includes results, record_2023
  end

  test "all_time_record scope returns all time record" do
    Record.create!(scope: "yearly", year: 2024)
    all_time_record = Record.create!(scope: "all_time")

    result = Record.all_time_record
    assert_equal all_time_record, result
  end

  test "current_year_record returns record for current year" do
    current_year = Time.current.year
    current_record = Record.create!(scope: "yearly", year: current_year)
    Record.create!(scope: "yearly", year: current_year - 1)

    result = Record.current_year_record
    assert_equal current_record, result
  end

  test "display_year_range returns 'All Time' for all_time scope" do
    record = Record.new(scope: "all_time")
    assert_equal "All Time", record.display_year_range
  end

  test "display_year_range includes 'Jan 1 - present' for current year" do
    current_year = Time.current.year
    record = Record.new(scope: "yearly", year: current_year)
    assert_equal "#{current_year} (Jan 1 - present)", record.display_year_range
  end

  test "display_year_range returns just year for past years" do
    record = Record.new(scope: "yearly", year: 2020)
    assert_equal "2020", record.display_year_range
  end

  test "yearly? returns true for yearly scope" do
    record = Record.new(scope: "yearly", year: 2024)
    assert record.yearly?
  end

  test "all_time? returns true for all_time scope" do
    record = Record.new(scope: "all_time")
    assert record.all_time?
  end

  test "can store temperature records" do
    record = Record.create!(
      scope: "yearly",
      year: 2024,
      highest_temp: 105.5,
      highest_temp_at: Time.current,
      lowest_temp: -10.2,
      lowest_temp_at: Time.current
    )

    assert_equal 105.5, record.highest_temp
    assert_equal(-10.2, record.lowest_temp)
  end

  test "can store wind records" do
    record = Record.create!(
      scope: "yearly",
      year: 2024,
      strongest_gust: 45.3,
      strongest_gust_at: Time.current,
      highest_wind_run: 250.5,
      highest_wind_run_date: Date.current
    )

    assert_equal 45.3, record.strongest_gust
    assert_equal 250.5, record.highest_wind_run
  end

  test "can store rain records" do
    record = Record.create!(
      scope: "yearly",
      year: 2024,
      highest_daily_rain: 5.25,
      highest_daily_rain_date: Date.current,
      wettest_month: 12,
      wettest_month_total: 15.75,
      wettest_month_year: 2024
    )

    assert_equal 5.25, record.highest_daily_rain
    assert_equal 12, record.wettest_month
    assert_equal 15.75, record.wettest_month_total
  end

  test "can store consecutive day records" do
    record = Record.create!(
      scope: "yearly",
      year: 2024,
      consecutive_rain_days: 10,
      consecutive_rain_start_date: Date.current,
      consecutive_dry_days: 45,
      consecutive_dry_start_date: Date.current - 50.days
    )

    assert_equal 10, record.consecutive_rain_days
    assert_equal 45, record.consecutive_dry_days
  end
end
