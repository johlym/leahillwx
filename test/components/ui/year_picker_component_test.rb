# frozen_string_literal: true

require "test_helper"

class Ui::YearPickerComponentTest < ViewComponent::TestCase
  test "renders a label wrapping the select element" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2022, 2023, 2024 ]
    ))

    assert_selector "label span", text: "Year"
    assert_selector "label select.ui-year-picker-select"
  end

  test "uses a custom label when provided" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/reports", current_year: 2024, years: [ 2024 ], label: "Season"
    ))

    assert_selector "label span", text: "Season"
  end

  test "renders one option per year" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2022, 2023, 2024 ]
    ))

    assert_selector "select option", count: 3
  end

  test "orders years newest first" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2022, 2024, 2023 ]
    ))

    labels = page.all("select option").map(&:text)
    assert_equal [ "2024", "2023", "2022" ], labels
  end

  test "deduplicates years" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2023, 2023, 2024, 2024 ]
    ))

    assert_selector "select option", count: 2
  end

  test "builds option values from base_path and year" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2023, 2024 ]
    ))

    assert_selector "select option[value='/records/2024']", text: "2024"
    assert_selector "select option[value='/records/2023']", text: "2023"
  end

  test "marks the current year option as selected" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2023, years: [ 2022, 2023, 2024 ]
    ))

    assert_selector "select option[selected][value='/records/2023']", text: "2023"
    assert_no_selector "select option[selected][value='/records/2024']"
  end

  test "compares current_year loosely (string vs integer)" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: "2023", years: [ 2022, 2023 ]
    ))

    assert_selector "select option[selected][value='/records/2023']"
  end

  test "omits the all-time option by default" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2024 ]
    ))

    assert_no_selector "select option[value='/records']"
  end

  test "includes an all-time option when include_all_time is true" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2023, 2024 ], include_all_time: true
    ))

    assert_selector "select option[value='/records']", text: "All time"
  end

  test "uses custom all_time_label when provided" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2024 ],
      include_all_time: true, all_time_label: "Everything"
    ))

    assert_selector "select option[value='/records']", text: "Everything"
  end

  test "marks all-time as selected when current_year is nil" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: nil, years: [ 2023, 2024 ], include_all_time: true
    ))

    assert_selector "select option[selected][value='/records']", text: "All time"
  end

  test "navigates on change to the selected value" do
    render_inline(Ui::YearPickerComponent.new(
      base_path: "/records", current_year: 2024, years: [ 2024 ]
    ))

    select = page.find("select")
    assert_includes select["onchange"], "window.location.href"
    assert_includes select["onchange"], "this.value"
  end
end
