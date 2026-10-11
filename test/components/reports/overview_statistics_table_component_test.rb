# frozen_string_literal: true

require "test_helper"

class Reports::OverviewStatisticsTableComponentTest < ViewComponent::TestCase
  setup do
    @report = Report.new(
      year: 2024,
      month: 1,
      month_mean_temp: 50.0,
      month_high_temp: 75.0,
      month_high_temp_day: 15,
      month_low_temp: 25.0,
      month_low_temp_day: 5,
      total_heat_degree_days: 450.0,
      total_cool_degree_days: 25.0,
      total_rain: 88.9,  # mm (displays as ~3.50 inches)
      avg_wind_speed: 3.8,  # m/s (displays as ~8.50 mph)
      month_high_wind_speed: 15.645,  # m/s (displays as ~35.00 mph)
      month_high_wind_day: 20,
      dominant_wind_dir: 180,
      dominant_wind_dir_compass: "S",
      month_mean_pressure: 1012.5,
      month_high_pressure: 1025.0,
      month_high_pressure_day: 10,
      month_low_pressure: 998.0,
      month_low_pressure_day: 3
    )
  end

  test "renders monthly overview heading" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report, type: :monthly))

    assert_selector "h2", text: "Monthly Overview"
  end

  test "renders daily overview heading when type is daily" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report, type: :daily, day: 1))

    assert_selector "h2", text: "Daily Overview"
  end

  test "renders table with correct structure" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "div.overview-statistics"
    assert_selector "table.stats-table"
    assert_selector "thead"
    assert_selector "tbody"
  end

  test "renders all column headers" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "th", text: "Mean Temp"
    assert_selector "th", text: "High Temp"
    assert_selector "th", text: "Low Temp"
    assert_selector "th", text: "Heat DD"
    assert_selector "th", text: "Cool DD"
    assert_selector "th", text: "Total Precip"
    assert_selector "th", text: "Mean Pressure"
    assert_selector "th", text: "High Pressure"
    assert_selector "th", text: "Low Pressure"
    assert_selector "th", text: "Avg Wind"
    assert_selector "th", text: "High Wind"
    assert_selector "th", text: "Wind Dir"
  end

  test "renders mean temperature" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /122\.00°/
  end

  test "renders high temperature with day" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /167\.00°/
    assert_selector "td span.stats-day-meta", text: "(Day 15)"
  end

  test "renders low temperature with day" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /77\.00°/
    assert_selector "td span.stats-day-meta", text: "(Day 5)"
  end

  test "renders N/A when high temp day is nil" do
    @report.month_high_temp_day = nil
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td span.stats-day-meta", text: "(Day N/A)"
  end

  test "renders degree days" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /450\.00/
    assert_selector "td", text: /25\.00/
  end

  test "renders total precipitation" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /3\.50 in\./
  end

  test "renders pressure statistics" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /1012\.5 hPa/
    assert_selector "td", text: /1025\.0 hPa/
    assert_selector "td span.stats-day-meta", text: "(Day 10)"
    assert_selector "td", text: /998\.0 hPa/
    assert_selector "td span.stats-day-meta", text: "(Day 3)"
  end

  test "renders average wind speed" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /8\.50 mph/
  end

  test "renders high wind speed with day" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /35\.00 mph/
    assert_selector "td span.stats-day-meta", text: "(Day 20)"
  end

  test "renders wind direction with vane component" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "td", text: /S/
    assert_selector "i.fa-location-arrow-up"
  end

  test "daily overview uses that day's totals instead of the month" do
    @report.entries.build(
      day: 11,
      hour: nil,
      mean_temp: 10.0,
      high_temp: 12.0,
      high_temp_time: "15:04",
      low_temp: 8.0,
      low_temp_time: "06:12",
      heat_degree_days: 12.5,
      cool_degree_days: 0.0,
      rain: 0.0,
      mean_pressure: 1013.0,
      high_pressure: 1016.0,
      high_pressure_time: "09:00",
      low_pressure: 1010.0,
      low_pressure_time: "16:00",
      avg_wind_speed: 1.0,
      high_wind_speed: 3.0,
      high_wind_time: "14:00",
      wind_dir: 180,
      wind_dir_compass: "S"
    )

    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report, type: :daily, day: 11))

    assert_selector "h2", text: "Daily Overview"
    assert_selector "td", text: /0\.00 in\./
    assert_no_selector "td", text: /3\.50 in\./
    assert_selector "td", text: /50\.00°/
    assert_selector "td span.stats-day-meta", text: "(@ 15:04)"
    assert_selector "td span.stats-day-meta", text: "(@ 06:12)"
  end

  test "defaults to monthly type" do
    render_inline(Reports::OverviewStatisticsTableComponent.new(report: @report))

    assert_selector "h2", text: "Monthly Overview"
  end
end
