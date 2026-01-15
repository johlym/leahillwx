# frozen_string_literal: true

require "test_helper"

class Records::RecordsComponentTest < ViewComponent::TestCase
  setup do
    @current_year = Time.current.year
    @selected_year = @current_year - 1
    @selected_year_record = Record.create!(scope: "yearly", year: @selected_year, highest_temp: 95.0)
    @current_year_record = Record.create!(scope: "yearly", year: @current_year, highest_temp: 90.0)
    @all_time_record = Record.create!(scope: "all_time", highest_temp: 105.0)
  end

  test "renders page title and subtitle" do
    render_inline(Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    ))

    assert_selector "h1", text: "Weather Records"
    assert_selector "p.subtitle", text: /Temperature.*Rain.*Wind Speed.*Pressure/
  end

  test "renders all section titles" do
    render_inline(Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    ))

    assert_selector "h2", text: "Temperature Records"
    assert_selector "h2", text: "Wind Records"
    assert_selector "h2", text: "Rain Records"
    assert_selector "h2", text: "Humidity Records"
    assert_selector "h2", text: "Barometer Records"
    assert_selector "h2", text: "Sun Records"
  end

  test "show_three_columns? returns true when selected year differs from current year" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    assert component.send(:show_three_columns?)
  end

  test "show_three_columns? returns false when selected year equals current year" do
    component = Records::RecordsComponent.new(
      selected_year_record: @current_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @current_year,
      current_year: @current_year
    )

    assert_not component.send(:show_three_columns?)
  end

  test "year_record returns selected_year_record when showing three columns" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    assert_equal @selected_year_record, component.send(:year_record)
  end

  test "year_record returns current_year_record when not showing three columns" do
    component = Records::RecordsComponent.new(
      selected_year_record: @current_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @current_year,
      current_year: @current_year
    )

    assert_equal @current_year_record, component.send(:year_record)
  end

  test "year_label includes 'Jan 1 - yesterday' for current year when not three columns" do
    component = Records::RecordsComponent.new(
      selected_year_record: @current_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @current_year,
      current_year: @current_year
    )

    assert_equal "#{@current_year} (Jan 1 - yesterday)", component.send(:year_label)
  end

  test "year_label returns just year for past years when three columns" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    assert_equal @selected_year.to_s, component.send(:year_label)
  end

  test "current_year_label always includes 'Jan 1 - yesterday'" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    assert_equal "#{@current_year} (Jan 1 - yesterday)", component.send(:current_year_label)
  end

  test "temperature_rows includes all temperature record types" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    rows = component.send(:temperature_rows)
    labels = rows.map { |r| r[:label] }

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
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    rows = component.send(:wind_rows)
    labels = rows.map { |r| r[:label] }

    assert_includes labels, "Strongest Gust"
    assert_includes labels, "Highest Daily Wind Run"
  end

  test "rain_rows includes rain record types" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    rows = component.send(:rain_rows)
    labels = rows.map { |r| r[:label] }

    assert_includes labels, "Highest Daily Rainfall"
    assert_includes labels, "Highest Daily Rain Rate"
    assert_includes labels, "Month with Most Rain"
    assert_includes labels, "Consecutive Days with Rain"
    assert_includes labels, "Consecutive Days without Rain"
  end

  test "humidity_rows includes humidity record types" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    rows = component.send(:humidity_rows)
    labels = rows.map { |r| r[:label] }

    assert_includes labels, "Highest Humidity"
    assert_includes labels, "Lowest Humidity"
    assert_includes labels, "Highest Dew Point"
    assert_includes labels, "Lowest Dew Point"
  end

  test "barometer_rows includes barometer record types" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    rows = component.send(:barometer_rows)
    labels = rows.map { |r| r[:label] }

    assert_includes labels, "Highest Pressure"
    assert_includes labels, "Lowest Pressure"
    assert_includes labels, "Largest Pressure Swing (Day)"
  end

  test "sun_rows includes solar record types" do
    component = Records::RecordsComponent.new(
      selected_year_record: @selected_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      selected_year: @selected_year,
      current_year: @current_year
    )

    rows = component.send(:sun_rows)
    labels = rows.map { |r| r[:label] }

    assert_includes labels, "Highest Solar Irradiance"
  end
end
