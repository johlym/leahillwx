# frozen_string_literal: true

require "test_helper"

class Records::RecordsComponentTest < ViewComponent::TestCase
  setup do
    @current_year = Time.current.year
    @selected_year = @current_year - 1
    @selected_year_record = Record.create!(scope: "yearly", year: @selected_year, highest_temp: 95.0)
    @all_time_record = Record.create!(scope: "all_time", highest_temp: 105.0)
  end

  def build(**overrides)
    Records::RecordsComponent.new(**default_kwargs.merge(overrides))
  end

  def default_kwargs
    {
      pivot: :year,
      selected_year: @selected_year,
      selected_year_record: @selected_year_record,
      all_time_record: @all_time_record,
      available_years: [ @selected_year, @current_year ],
      heatmap_year: @selected_year,
      heatmap_days: []
    }
  end

  test "renders pivot title as a section header" do
    render_inline(build(pivot: :year))

    assert_selector "h2", text: "#{@selected_year} Records"
  end

  test "renders all-time pivot title when pivot is :all_time" do
    render_inline(build(pivot: :all_time, selected_year: nil))

    assert_selector "h2", text: "All-Time Records"
  end

  test "renders month pivot title with month name and year" do
    render_inline(build(pivot: :month, selected_month: 3))

    assert_selector "h2", text: "March #{@selected_year} Records"
  end

  test "renders all section titles in year pivot" do
    render_inline(build(pivot: :year))

    %w[Temperature Wind Rain Humidity Barometer Sun].each do |title|
      assert_selector "h3", text: title
    end
  end

  test "renders year picker with available years" do
    render_inline(build(available_years: [ 2022, 2023, @current_year ]))

    assert_selector "select.ui-year-picker-select"
    assert_selector "select option", text: "2022"
    assert_selector "select option", text: "2023"
    assert_selector "select option", text: "All time"
  end

  test "renders empty-state message when active_record is nil" do
    empty_year_record = Record.create!(scope: "yearly", year: @selected_year - 5)

    render_inline(Records::RecordsComponent.new(
      pivot: :year,
      selected_year: @selected_year - 5,
      selected_year_record: nil,
      all_time_record: @all_time_record,
      available_years: [ @selected_year - 5 ],
      heatmap_year: @selected_year - 5,
      heatmap_days: []
    ))

    assert_text(/No records available yet/)
    # No section headers when there's no data
    assert_no_selector "h3", text: "Temperature"
    empty_year_record.destroy
  end

  test "pivot_year? is true only for :year pivot" do
    assert build(pivot: :year).send(:pivot_year?)
    assert_not build(pivot: :month, selected_month: 1).send(:pivot_year?)
    assert_not build(pivot: :all_time, selected_year: nil).send(:pivot_year?)
  end

  test "pivot_month? is true only for :month pivot" do
    assert_not build(pivot: :year).send(:pivot_month?)
    assert build(pivot: :month, selected_month: 1).send(:pivot_month?)
    assert_not build(pivot: :all_time, selected_year: nil).send(:pivot_month?)
  end

  test "active_record returns selected_year_record in year pivot" do
    component = build(pivot: :year)

    assert_equal @selected_year_record, component.send(:active_record)
  end

  test "active_record returns all_time_record in all-time pivot" do
    component = build(pivot: :all_time, selected_year: nil)

    assert_equal @all_time_record, component.send(:active_record)
  end

  test "temperature_rows includes all temperature record types" do
    labels = build.send(:temperature_rows).map { |r| r[:label] }

    assert_includes labels, "Highest Temperature"
    assert_includes labels, "Lowest Temperature"
    assert_includes labels, "Highest Apparent Temperature"
    assert_includes labels, "Lowest Apparent Temperature"
    assert_includes labels, "Highest Heat Index"
    assert_includes labels, "Lowest Wind Chill"
    assert_includes labels, "Largest Daily Temperature Range"
    assert_includes labels, "Smallest Daily Temperature Range"
  end

  test "wind_rows includes wind record types" do
    labels = build.send(:wind_rows).map { |r| r[:label] }

    assert_includes labels, "Strongest Gust"
    assert_includes labels, "Highest Daily Wind Run"
  end

  test "rain_rows includes rain record types" do
    labels = build.send(:rain_rows).map { |r| r[:label] }

    assert_includes labels, "Highest Daily Rainfall"
    assert_includes labels, "Highest Daily Rain Rate"
    assert_includes labels, "Wettest Month"
    assert_includes labels, "Longest Rainy Streak"
    assert_includes labels, "Longest Dry Streak"
  end

  test "humidity_rows includes humidity record types" do
    labels = build.send(:humidity_rows).map { |r| r[:label] }

    assert_includes labels, "Highest Humidity"
    assert_includes labels, "Lowest Humidity"
    assert_includes labels, "Highest Dew Point"
    assert_includes labels, "Lowest Dew Point"
  end

  test "barometer_rows includes barometer record types" do
    labels = build.send(:barometer_rows).map { |r| r[:label] }

    assert_includes labels, "Highest Pressure"
    assert_includes labels, "Lowest Pressure"
    assert_includes labels, "Largest Daily Pressure Swing"
  end

  test "sun_rows includes solar record types" do
    labels = build.send(:sun_rows).map { |r| r[:label] }

    assert_includes labels, "Highest Solar Irradiance"
  end

  test "months_available_for_pivot returns sorted months for the selected year" do
    component = build(
      pivot: :year,
      selected_year: 2024,
      available_report_months_by_year: { 2024 => [ 3, 1, 2 ], 2023 => [ 12 ] }
    )

    assert_equal [ 1, 2, 3 ], component.send(:months_available_for_pivot)
  end

  test "months_available_for_pivot falls back to most recent year when none selected" do
    component = build(
      pivot: :all_time,
      selected_year: nil,
      available_report_months_by_year: { 2023 => [ 10 ], 2024 => [ 5, 6 ] }
    )

    assert_equal [ 5, 6 ], component.send(:months_available_for_pivot)
  end

  test "months_available_for_pivot returns empty when no months available" do
    component = build(available_report_months_by_year: {})

    assert_equal [], component.send(:months_available_for_pivot)
  end
end
