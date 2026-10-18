# frozen_string_literal: true

require "test_helper"

class Records::RecordCardComponentTest < ViewComponent::TestCase
  def solar_row
    {
      label: "Highest Solar Irradiance",
      field: :highest_solar,
      type: :solar,
      timestamp_field: :highest_solar_at,
      timestamp_type: :datetime
    }
  end

  test "converts stored lux to W/m² on the solar card and sparkline" do
    record = Record.new(
      scope: "yearly",
      year: 2024,
      highest_solar: 10_000,
      highest_solar_at: Time.zone.parse("2024-07-01 15:00:00")
    )
    history = [
      Record.new(scope: "yearly", year: 2022, highest_solar: nil),
      Record.new(scope: "yearly", year: 2023, highest_solar: 10_000),
      Record.new(scope: "yearly", year: 2024, highest_solar: 20_000)
    ]

    render_inline(Records::RecordCardComponent.new(row: solar_row, record: record, history: history))

    assert_selector ".record-card-value-number", text: "79.0"
    assert_selector ".record-card-value-unit", text: "W/m²"

    data = JSON.parse(page.find("[data-chart-data-value]")["data-chart-data-value"])
    assert_equal [ nil, 79.0, 158.0 ], data.dig("datasets", 0, "data")
  end

  test "shows a dash when the solar record has no light reading" do
    record = Record.new(scope: "yearly", year: 2024, highest_solar: nil)

    render_inline(Records::RecordCardComponent.new(row: solar_row, record: record))

    assert_selector ".record-card-value-number", text: "—"
    assert_no_selector ".record-card-value-unit"
  end
end
