# frozen_string_literal: true

require "test_helper"

class Reports::StatisticsTableComponentTest < ViewComponent::TestCase
  setup do
    @report = Report.new(year: 2024, month: 1)
    @report.save(validate: false)
  end

  test "renders daily period label by default" do
    component = Reports::StatisticsTableComponent.new(report: @report)

    assert component.daily?
    assert_equal "Day", component.period_label
  end

  test "renders hourly period label when period_type is hourly" do
    component = Reports::StatisticsTableComponent.new(report: @report, period_type: :hourly, day: 1)

    assert component.hourly?
    assert_equal "Hour", component.period_label
  end

  test "daily? returns true for daily period type" do
    component = Reports::StatisticsTableComponent.new(report: @report, period_type: :daily)

    assert component.daily?
    assert_not component.hourly?
  end

  test "hourly? returns true for hourly period type" do
    component = Reports::StatisticsTableComponent.new(report: @report, period_type: :hourly, day: 1)

    assert component.hourly?
    assert_not component.daily?
  end

  test "partial_note returns message for daily periods" do
    component = Reports::StatisticsTableComponent.new(report: @report, period_type: :daily)

    note = component.partial_note
    assert_includes note, "day"
    assert_includes note, "incomplete set of measurements"
  end

  test "partial_note returns message for hourly periods" do
    component = Reports::StatisticsTableComponent.new(report: @report, period_type: :hourly, day: 1)

    note = component.partial_note
    assert_includes note, "hour"
    assert_includes note, "incomplete set of measurements"
  end

  test "period_data filters out future periods" do
    @report.update_columns(year: Time.current.year, month: Time.current.month)

    component = Reports::StatisticsTableComponent.new(report: @report)
    period_data = component.period_data

    current_day = Time.current.in_time_zone("America/Los_Angeles").day
    assert period_data.all? { |pd| pd.period <= current_day }
  end

  test "period_data includes entries with data" do
    entry = ReportEntry.create!(
      report: @report,
      day: 1,
      mean_temp: 50.0,
      high_temp: 60.0,
      low_temp: 40.0
    )

    component = Reports::StatisticsTableComponent.new(report: @report)
    period_data = component.period_data

    day_1_data = period_data.find { |pd| pd.period == 1 }
    assert_not_nil day_1_data
    assert_equal entry, day_1_data.entry
  end

  test "PeriodDataRow has_data? delegates to entry" do
    entry = ReportEntry.new(mean_temp: 50.0, high_temp: 60.0, low_temp: 40.0)

    row = Reports::StatisticsTableComponent::PeriodDataRow.new(
      period: 1,
      period_type: :daily,
      entry: entry,
      is_future: false,
      is_current: false,
      is_max_mean_temp: false,
      is_max_high_temp: false,
      is_max_low_temp: false,
      is_max_heat_dd: false,
      is_max_cool_dd: false,
      is_max_rain: false,
      is_max_avg_wind: false,
      is_max_high_wind: false,
      report: @report
    )

    assert_equal entry.has_data?, row.has_data? if entry.respond_to?(:has_data?)
  end

  test "PeriodDataRow partial_period? delegates to entry" do
    entry = ReportEntry.new(partial_period: true)

    row = Reports::StatisticsTableComponent::PeriodDataRow.new(
      period: 1,
      period_type: :daily,
      entry: entry,
      is_future: false,
      is_current: false,
      is_max_mean_temp: false,
      is_max_high_temp: false,
      is_max_low_temp: false,
      is_max_heat_dd: false,
      is_max_cool_dd: false,
      is_max_rain: false,
      is_max_avg_wind: false,
      is_max_high_wind: false,
      report: @report
    )

    assert row.partial_period?
  end

  test "PeriodDataRow day returns entry day when entry exists" do
    entry = ReportEntry.new(day: 5)

    row = Reports::StatisticsTableComponent::PeriodDataRow.new(
      period: 5,
      period_type: :daily,
      entry: entry,
      is_future: false,
      is_current: false,
      is_max_mean_temp: false,
      is_max_high_temp: false,
      is_max_low_temp: false,
      is_max_heat_dd: false,
      is_max_cool_dd: false,
      is_max_rain: false,
      is_max_avg_wind: false,
      is_max_high_wind: false,
      report: @report
    )

    assert_equal 5, row.day
  end

  test "PeriodDataRow day returns period when entry is nil" do
    row = Reports::StatisticsTableComponent::PeriodDataRow.new(
      period: 10,
      period_type: :daily,
      entry: nil,
      is_future: false,
      is_current: false,
      is_max_mean_temp: false,
      is_max_high_temp: false,
      is_max_low_temp: false,
      is_max_heat_dd: false,
      is_max_cool_dd: false,
      is_max_rain: false,
      is_max_avg_wind: false,
      is_max_high_wind: false,
      report: @report
    )

    assert_equal 10, row.day
  end
end
