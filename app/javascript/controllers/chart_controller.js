import { Controller } from "@hotwired/stimulus"
import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  BarController,
  BarElement,
  LinearScale,
  CategoryScale,
  TimeScale,
  Tooltip,
  Legend,
  Filler,
  DoughnutController,
  ArcElement,
} from "chart.js"
import { readPaletteColors, withAlpha, observePaletteChanges } from "./helpers/palette"

Chart.register(
  LineController,
  LineElement,
  PointElement,
  BarController,
  BarElement,
  LinearScale,
  CategoryScale,
  TimeScale,
  Tooltip,
  Legend,
  Filler,
  DoughnutController,
  ArcElement,
)

// Renders a Chart.js chart driven by data-attributes from
// Ui::ChartComponent. Reads the current palette's CSS custom
// properties so every chart re-themes when the palette changes.
//
// Values:
//   data-chart-type-value: "line" | "bar" | "doughnut"
//   data-chart-data-value: {
//     labels: [...],
//     datasets: [{ label, key, data, color?, dashed?, fill?, stack?, yAxisID?, type? }]
//   }
//   data-chart-options-value: {
//     yUnit, y2Unit, xUnit, stacked, beginAtZero, aspectRatio,
//     yLabel, xLabel, hideLegend, hideGrid, band: { fromKey, toKey }
//   }
export default class extends Controller {
  static values = {
    type: String,
    data: Object,
    options: Object,
  }

  connect() {
    this.canvas = document.createElement("canvas")
    this.canvas.setAttribute("role", "img")
    this.element.appendChild(this.canvas)
    this.buildChart()
    this.paletteObserver = observePaletteChanges(() => this.applyPaletteTheme())
  }

  disconnect() {
    if (this.chart) this.chart.destroy()
    if (this.paletteObserver) this.paletteObserver.disconnect()
    if (this.canvas && this.canvas.parentNode === this.element) {
      this.element.removeChild(this.canvas)
    }
  }

  buildChart() {
    const type = this.typeValue || "line"
    const data = this.dataValue || {}
    const options = this.optionsValue || {}

    const paletteColors = readPaletteColors()
    const datasets = this.buildDatasets(data.datasets || [], paletteColors, options)

    const config = {
      type,
      data: { labels: data.labels || [], datasets },
      options: this.buildChartOptions(options, paletteColors, type),
    }

    this.chart = new Chart(this.canvas.getContext("2d"), config)
  }

  applyPaletteTheme() {
    if (!this.chart) return
    const paletteColors = readPaletteColors()
    const options = this.optionsValue || {}

    const datasets = this.buildDatasets(this.dataValue.datasets || [], paletteColors, options)
    this.chart.data.datasets = datasets.map((d, i) => ({ ...this.chart.data.datasets[i], ...d }))
    this.chart.options = this.buildChartOptions(options, paletteColors, this.typeValue)
    this.chart.update("none")
  }

  buildDatasets(rawDatasets, palette, options) {
    return rawDatasets.map((ds, i) => {
      const color = this.resolveColor(
        ds.color,
        palette.chartColors[i % palette.chartColors.length],
      )
      const base = {
        label: ds.label,
        data: ds.data,
        borderColor: color,
        backgroundColor: ds.fill
          ? withAlpha(color, ds.fillAlpha ?? 0.15)
          : color,
        borderWidth: ds.borderWidth ?? 2,
        borderDash: ds.dashed ? [6, 4] : undefined,
        pointRadius: ds.pointRadius ?? 0,
        pointHoverRadius: 5,
        pointHitRadius: 8,
        tension: ds.tension ?? 0.25,
        fill: ds.fill ?? false,
        stack: ds.stack,
        yAxisID: ds.yAxisID,
        type: ds.type,
        hidden: ds.hidden ?? false,
        spanGaps: ds.spanGaps ?? true,
      }
      if (ds.fillTarget !== undefined) {
        base.fill = {
          target: ds.fillTarget,
          above: withAlpha(color, 0.15),
          below: withAlpha(color, 0.15),
        }
      }
      return base
    })
  }

  buildChartOptions(options, palette, type) {
    const scales = type === "doughnut" ? undefined : this.buildScales(options, palette)
    return {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: "index",
        intersect: false,
      },
      plugins: {
        legend: {
          display: !options.hideLegend,
          position: options.legendPosition || "top",
          labels: {
            color: palette.text,
            usePointStyle: true,
            padding: 16,
            boxWidth: 10,
          },
        },
        tooltip: {
          backgroundColor: palette.surface2,
          titleColor: palette.textStrong,
          bodyColor: palette.text,
          borderColor: palette.border,
          borderWidth: 1,
          padding: 10,
          cornerRadius: 6,
          usePointStyle: true,
          callbacks: this.buildTooltipCallbacks(options),
        },
      },
      scales,
    }
  }

  buildScales(options, palette) {
    const gridColor = withAlpha(palette.border, 0.4)
    const tickColor = palette.muted
    const scales = {
      x: {
        stacked: options.stacked ?? false,
        grid: { display: !options.hideGrid, color: gridColor, tickColor: gridColor },
        border: { color: gridColor },
        ticks: {
          color: tickColor,
          maxRotation: 0,
          autoSkip: true,
          autoSkipPadding: 12,
        },
        title: options.xLabel
          ? { display: true, text: options.xLabel, color: palette.muted }
          : undefined,
      },
      y: {
        stacked: options.stacked ?? false,
        beginAtZero: options.beginAtZero ?? false,
        grid: { display: !options.hideGrid, color: gridColor, tickColor: gridColor },
        border: { color: gridColor },
        ticks: {
          color: tickColor,
          callback: (v) => (options.yUnit ? `${v}${options.yUnit}` : v),
        },
        title: options.yLabel
          ? { display: true, text: options.yLabel, color: palette.muted }
          : undefined,
      },
    }
    if (options.y2Unit || options.y2Label) {
      scales.y2 = {
        position: "right",
        grid: { display: false },
        border: { color: gridColor },
        ticks: {
          color: tickColor,
          callback: (v) => (options.y2Unit ? `${v}${options.y2Unit}` : v),
        },
        title: options.y2Label
          ? { display: true, text: options.y2Label, color: palette.muted }
          : undefined,
      }
    }
    return scales
  }

  buildTooltipCallbacks(options) {
    return {
      label: (item) => {
        const val = item.parsed.y
        if (val === null || val === undefined) return null
        const unit = options.yUnit || ""
        const formatted =
          typeof val === "number" ? this.formatNumber(val, options.decimals ?? 1) : val
        return `${item.dataset.label}: ${formatted}${unit}`
      },
    }
  }

  formatNumber(v, decimals) {
    if (Number.isInteger(v) && decimals === 0) return v.toString()
    return Number(v).toFixed(decimals)
  }

  // Chart.js hands the string straight to the canvas API, which
  // doesn't understand `var(--...)`. Resolve to the concrete computed
  // value; if the server passed a plain color (oklch, hex, rgb, etc.)
  // pass it through unchanged.
  resolveColor(candidate, fallback) {
    if (!candidate) return fallback
    if (typeof candidate !== "string") return candidate
    const match = candidate.trim().match(/^var\(\s*(--[a-zA-Z0-9-]+)\s*(?:,\s*(.+))?\)$/)
    if (!match) return candidate
    const [, name, defaultVal] = match
    const resolved = getComputedStyle(document.documentElement)
      .getPropertyValue(name)
      .trim()
    if (resolved) return resolved
    if (defaultVal) return defaultVal.trim()
    return fallback
  }
}
