# frozen_string_literal: true

require "test_helper"

class Ui::ChartComponentTest < ViewComponent::TestCase
  def default_data
    { labels: [ "Jan", "Feb", "Mar" ], datasets: [ { label: "High", key: "high", data: [ 70, 72, 78 ] } ] }
  end

  test "renders a figure with a chart frame" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data))

    assert_selector "figure div.ui-chart-frame"
  end

  test "does not render a figcaption when no title or subtitle" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data))

    assert_no_selector "figcaption"
  end

  test "renders title in the figcaption when provided" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data, title: "Temperature"))

    assert_selector "figcaption span", text: "Temperature"
  end

  test "renders subtitle in the figcaption when provided" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data, title: "Temp", subtitle: "Last 30 days"))

    assert_selector "figcaption span", text: "Temp"
    assert_selector "figcaption span", text: "Last 30 days"
  end

  test "wires up the stimulus chart controller with type and data" do
    render_inline(Ui::ChartComponent.new(type: :bar, data: default_data))

    frame = page.find("div.ui-chart-frame")
    assert_equal "chart", frame["data-controller"]
    assert_equal "bar", frame["data-chart-type-value"]

    data_json = JSON.parse(frame["data-chart-data-value"])
    assert_equal [ "Jan", "Feb", "Mar" ], data_json["labels"]
  end

  test "serializes options to JSON on the chart frame" do
    options = { yUnit: "°F", stacked: false }
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data, options: options))

    frame = page.find("div.ui-chart-frame")
    options_json = JSON.parse(frame["data-chart-options-value"])
    assert_equal "°F", options_json["yUnit"]
    assert_equal false, options_json["stacked"]
  end

  test "applies height as a CSS custom property" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data, height: 420))

    frame = page.find("div.ui-chart-frame")
    assert_includes frame["style"], "--chart-height: 420px"
  end

  test "coerces non-integer heights to integer pixels" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data, height: "550"))

    frame = page.find("div.ui-chart-frame")
    assert_includes frame["style"], "--chart-height: 550px"
  end

  test "uses explicit aria_label when provided" do
    render_inline(Ui::ChartComponent.new(
      type: "line", data: default_data, title: "Temp", aria_label: "Daily highs and lows"
    ))

    assert_selector "div.ui-chart-frame[role='img'][aria-label='Daily highs and lows']"
  end

  test "falls back to title as aria-label when no explicit aria_label" do
    render_inline(Ui::ChartComponent.new(type: "line", data: default_data, title: "Temperature"))

    assert_selector "div.ui-chart-frame[aria-label='Temperature']"
  end
end
