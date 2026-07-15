# frozen_string_literal: true

# Compact sparkline for home live tiles.
# Plots the 10-minute average as a single accent line across today's absolute
# day (00:00 → 23:50). Y-axis is scaled to today's low/high so far and only
# those endpoint labels are shown. Optional `markers` (e.g. wind gusts)
# render as a secondary dashed line. `metric` keys the tile for live websocket
# updates.
class Home::CurrentWeather::LiveSparklineComponent < ViewComponent::Base
  def initialize(series:, metric:, y_unit: "", aria_label:, decimals: 0)
    @series = series || { labels: [], values: [] }
    @metric = metric
    @y_unit = y_unit
    @aria_label = aria_label
    @decimals = decimals
  end

  def render?
    @metric.present?
  end

  def call
    content_tag(
      :div,
      "",
      class: "live-tile-sparkline",
      data: {
        controller: "chart",
        live_sparkline: @metric,
        live_sparkline_decimals: @decimals,
        live_sparkline_y_unit: @y_unit,
        chart_type_value: "line",
        chart_data_value: chart_data.to_json,
        chart_options_value: chart_options.to_json
      },
      role: "img",
      "aria-label": @aria_label
    )
  end

  private

  def chart_data
    datasets = [
      {
        label: "Average",
        data: @series[:values] || [],
        color: "var(--accent)",
        borderWidth: 1.6,
        tension: 0.35,
        spanGaps: true,
        fill: true,
        fillAlpha: 0.12
      }
    ]

    if @series[:markers].present?
      datasets << {
        label: "Gust",
        data: @series[:markers],
        color: "var(--accent)",
        colorAlpha: 0.75,
        borderWidth: 1.4,
        tension: 0.35,
        dashed: true,
        fill: false,
        spanGaps: true,
        pointRadius: 0
      }
    end

    {
      labels: @series[:labels] || [],
      datasets: datasets
    }
  end

  def chart_options
    options = {
      hideLegend: true,
      hideGrid: true,
      hideXAxis: true,
      yTicks: "minmax",
      tooltipFormat: "hourValue",
      styleGaps: true,
      livePulse: true,
      decimals: @decimals,
      yUnit: @y_unit
    }
    options[:yMin] = @series[:y_min] if @series[:y_min]
    options[:yMax] = @series[:y_max] if @series[:y_max]
    options
  end
end
