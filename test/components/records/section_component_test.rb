# frozen_string_literal: true

require "test_helper"

class Records::SectionComponentTest < ViewComponent::TestCase
  setup do
    @year_record = Record.create!(scope: "yearly", year: 2023, highest_temp: 95.0)
    @current_year_record = Record.create!(scope: "yearly", year: Time.current.year, highest_temp: 90.0)
    @all_time_record = Record.create!(scope: "all_time", highest_temp: 105.0)

    @rows = [
      {
        label: "Highest Temperature",
        field: :highest_temp,
        type: :temp,
        timestamp_field: :highest_temp_at,
        timestamp_type: :datetime
      }
    ]
  end

  test "renders section with title" do
    render_inline(Records::SectionComponent.new(
      title: "Temperature Records",
      rows: @rows,
      year_record: @year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      year_label: "2023",
      current_year_label: "2024 (Jan 1 - yesterday)",
      show_three_columns: true
    ))

    assert_selector "div.records-section"
    assert_selector "h2", text: "Temperature Records"
  end

  test "enriched_rows adds record references to each row" do
    component = Records::SectionComponent.new(
      title: "Test Section",
      rows: @rows,
      year_record: @year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      year_label: "2023",
      current_year_label: "2024 (Jan 1 - yesterday)",
      show_three_columns: true
    )

    enriched = component.send(:enriched_rows)

    assert_equal 1, enriched.length
    first_row = enriched.first

    assert_equal @year_record, first_row[:year_record]
    assert_equal @current_year_record, first_row[:current_year_record]
    assert_equal @all_time_record, first_row[:all_time_record]
    assert_equal "Highest Temperature", first_row[:label]
  end

  test "enriched_rows preserves original row data" do
    component = Records::SectionComponent.new(
      title: "Test Section",
      rows: @rows,
      year_record: @year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      year_label: "2023",
      current_year_label: "2024 (Jan 1 - yesterday)",
      show_three_columns: true
    )

    enriched = component.send(:enriched_rows)
    first_row = enriched.first

    assert_equal :highest_temp, first_row[:field]
    assert_equal :temp, first_row[:type]
    assert_equal :highest_temp_at, first_row[:timestamp_field]
    assert_equal :datetime, first_row[:timestamp_type]
  end

  test "handles multiple rows" do
    multi_rows = [
      { label: "Highest Temperature", field: :highest_temp, type: :temp },
      { label: "Lowest Temperature", field: :lowest_temp, type: :temp },
      { label: "Highest Humidity", field: :highest_humidity, type: :humidity }
    ]

    component = Records::SectionComponent.new(
      title: "Multiple Records",
      rows: multi_rows,
      year_record: @year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      year_label: "2023",
      current_year_label: "2024 (Jan 1 - yesterday)",
      show_three_columns: true
    )

    enriched = component.send(:enriched_rows)

    assert_equal 3, enriched.length
    assert_equal "Highest Temperature", enriched[0][:label]
    assert_equal "Lowest Temperature", enriched[1][:label]
    assert_equal "Highest Humidity", enriched[2][:label]
  end

  test "works with show_three_columns false" do
    component = Records::SectionComponent.new(
      title: "Test Section",
      rows: @rows,
      year_record: @current_year_record,
      current_year_record: @current_year_record,
      all_time_record: @all_time_record,
      year_label: "2024 (Jan 1 - yesterday)",
      current_year_label: "2024 (Jan 1 - yesterday)",
      show_three_columns: false
    )

    enriched = component.send(:enriched_rows)

    assert_equal 1, enriched.length
    assert_equal @current_year_record, enriched.first[:year_record]
  end
end
