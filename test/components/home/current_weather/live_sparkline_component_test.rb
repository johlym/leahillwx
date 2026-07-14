# frozen_string_literal: true

require "test_helper"

class Home::CurrentWeather::LiveSparklineComponentTest < ViewComponent::TestCase
  test "renders a single average line scaled to overall high/low" do
    series = {
      labels: [ "12 pm", "1 pm", "2 pm" ],
      values: [ 10, 12, 14 ],
      y_min: 8,
      y_max: 16
    }

    render_inline(
      Home::CurrentWeather::LiveSparklineComponent.new(
        series: series,
        y_unit: "%",
        decimals: 0,
        aria_label: "Hourly average humidity over the last 24 hours"
      )
    )

    assert_selector ".live-tile-sparkline[data-controller='chart']"
    assert_selector ".live-tile-sparkline[aria-label='Hourly average humidity over the last 24 hours']"

    data = JSON.parse(page.find(".live-tile-sparkline")["data-chart-data-value"])
    assert_equal 1, data["datasets"].length
    assert_equal "Average", data["datasets"][0]["label"]
    assert_equal "var(--accent)", data["datasets"][0]["color"]
    assert_equal [ 10, 12, 14 ], data["datasets"][0]["data"]
    assert_equal [ "12 pm", "1 pm", "2 pm" ], data["labels"]

    options = JSON.parse(page.find(".live-tile-sparkline")["data-chart-options-value"])
    assert_equal true, options["hideLegend"]
    assert_equal true, options["hideXAxis"]
    assert_equal "minmax", options["yTicks"]
    assert_equal "hourValue", options["tooltipFormat"]
    assert_equal true, options["styleGaps"]
    assert_equal 8, options["yMin"]
    assert_equal 16, options["yMax"]
  end

  test "renders gust as a secondary dashed line when markers are present" do
    series = {
      labels: [ "12 pm", "1 pm", "2 pm" ],
      values: [ 5, 7, 6 ],
      markers: [ 12, 15, 11 ],
      y_min: 3,
      y_max: 15
    }

    render_inline(
      Home::CurrentWeather::LiveSparklineComponent.new(
        series: series,
        y_unit: " mph",
        decimals: 0,
        aria_label: "Hourly average wind speed over the last 24 hours"
      )
    )

    data = JSON.parse(page.find(".live-tile-sparkline")["data-chart-data-value"])
    assert_equal 2, data["datasets"].length
    gust = data["datasets"][1]
    assert_equal "Gust", gust["label"]
    assert_equal true, gust["dashed"]
    assert_equal 0.75, gust["colorAlpha"]
    assert_equal [ 12, 15, 11 ], gust["data"]
  end

  test "does not render when series is too sparse" do
    render_inline(
      Home::CurrentWeather::LiveSparklineComponent.new(
        series: { labels: [ "" ], values: [ 1 ], y_min: 1, y_max: 1 },
        aria_label: "Sparse"
      )
    )

    assert_no_selector ".live-tile-sparkline"
  end
end
