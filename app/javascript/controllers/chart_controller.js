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
import { gapHatchPlugin } from "./helpers/gap_hatch_plugin"

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
  gapHatchPlugin,
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
//     yLabel, xLabel, hideLegend, hideGrid, hideAxes, hideXAxis,
//     yTicks: "minmax" | undefined, tooltipFormat: "hourValue" | undefined,
//     styleGaps: true to dash + hatch segments that bridge missing points,
//     decimals, band: { fromKey, toKey }
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
      let color = this.resolveColor(
        ds.color,
        palette.chartColors[i % palette.chartColors.length],
      )
      if (typeof ds.colorAlpha === "number") {
        color = withAlpha(color, ds.colorAlpha)
      }
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
        pointHoverRadius: ds.pointHoverRadius ?? 5,
        pointHitRadius: ds.pointHitRadius ?? 8,
        tension: ds.tension ?? 0.25,
        fill: ds.fill ?? false,
        stack: ds.stack,
        yAxisID: ds.yAxisID,
        type: ds.type,
        hidden: ds.hidden ?? false,
        spanGaps: ds.spanGaps ?? true,
        showLine: ds.showLine,
      }
      if (ds.fillTarget !== undefined) {
        base.fill = {
          target: ds.fillTarget,
          above: withAlpha(color, 0.15),
          below: withAlpha(color, 0.15),
        }
      }
      // Gap dash/hatch only on the primary solid series — companion
      // dashed lines (e.g. wind gusts) already read as secondary.
      if (options.styleGaps && ds.showLine !== false && !ds.dashed) {
        base.spanGaps = true
        base.segment = {
          borderDash: (ctx) => (isGapSegment(ctx) ? [4, 3] : undefined),
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
          displayColors: options.tooltipFormat !== "hourValue",
          callbacks: this.buildTooltipCallbacks(options),
        },
        gapHatch: {
          enabled: options.styleGaps === true,
        },
      },
      scales,
    }
  }

  buildScales(options, palette) {
    const gridColor = withAlpha(palette.border, 0.4)
    const tickColor = palette.muted
    const hideAxes = options.hideAxes === true
    const hideXAxis = hideAxes || options.hideXAxis === true
    const showYAxis = !hideAxes
    const showGrid = !hideAxes && !options.hideGrid
    const yTickCallback = (v) => {
      const decimals = options.decimals
      const formatted =
        typeof v === "number" && decimals !== undefined
          ? this.formatNumber(v, decimals)
          : v
      return options.yUnit ? `${formatted}${options.yUnit}` : formatted
    }
    const yTicks = {
      color: tickColor,
      callback: yTickCallback,
    }
    // Sparkline-style: only the scale min/max (high/low) labels.
    // Exact endpoints are enforced in afterBuildTicks below.
    const scales = {
      x: {
        stacked: options.stacked ?? false,
        display: !hideXAxis,
        grid: { display: showGrid, color: gridColor, tickColor: gridColor },
        border: { display: !hideXAxis, color: gridColor },
        ticks: {
          color: tickColor,
          maxRotation: 0,
          autoSkip: true,
          autoSkipPadding: 12,
          display: !hideXAxis,
        },
        title: options.xLabel && !hideXAxis
          ? { display: true, text: options.xLabel, color: palette.muted }
          : undefined,
      },
      y: {
        stacked: options.stacked ?? false,
        display: showYAxis,
        beginAtZero: options.beginAtZero ?? false,
        grid: { display: showGrid, color: gridColor, tickColor: gridColor },
        border: { display: showYAxis, color: gridColor },
        ticks: yTicks,
        title: options.yLabel && showYAxis
          ? { display: true, text: options.yLabel, color: palette.muted }
          : undefined,
      },
    }
    if (options.yMin !== undefined && options.yMin !== null) scales.y.min = options.yMin
    if (options.yMax !== undefined && options.yMax !== null) scales.y.max = options.yMax
    if (
      options.yMin !== undefined && options.yMin !== null &&
      options.yMax !== undefined && options.yMax !== null &&
      options.yMin === options.yMax
    ) {
      const pad = Math.abs(options.yMin) > 0 ? Math.abs(options.yMin) * 0.05 : 0.5
      scales.y.min = options.yMin - pad
      scales.y.max = options.yMax + pad
    }
    if (options.yTicks === "minmax") {
      const dataMin = options.yMin
      const dataMax = options.yMax
      scales.y.afterBuildTicks = (axis) => {
        if (dataMin === undefined || dataMin === null || dataMax === undefined || dataMax === null) {
          const min = axis.min
          const max = axis.max
          axis.ticks = min === max ? [{ value: min }] : [{ value: min }, { value: max }]
          return
        }
        axis.ticks =
          dataMin === dataMax ? [{ value: dataMin }] : [{ value: dataMin }, { value: dataMax }]
      }
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
    if (options.tooltipFormat === "hourValue") {
      return {
        title: () => "",
        label: (item) => {
          // Companion series (e.g. gust) is folded into the primary label.
          if (item.dataset.label === "Gust") return null

          const val = item.parsed.y
          if (val === null || val === undefined) return null
          const unit = options.yUnit || ""
          const decimals = options.decimals ?? 1
          const formatted =
            typeof val === "number" ? this.formatNumber(val, decimals) : val
          const hour = item.label || ""

          const gustDataset = item.chart.data.datasets.find((d) => d.label === "Gust")
          const gust = gustDataset?.data?.[item.dataIndex]
          if (typeof gust === "number") {
            return `${hour}: ${formatted}${unit} (${this.formatNumber(gust, decimals)})`
          }
          return `${hour}: ${formatted}${unit}`
        },
      }
    }

    return {
      label: (item) => {
        const val = item.parsed.y
        if (val === null || val === undefined) return null
        const axis = item.dataset.yAxisID || "y"
        const unit = axis === "y2" ? (options.y2Unit || "") : (options.yUnit || "")
        const formatted =
          typeof val === "number" ? this.formatNumber(val, options.decimals ?? 1) : val
        return `${item.dataset.label}: ${formatted}${unit}`
      },
    }
  }

  formatNumber(v, decimals) {
    if (Number.isInteger(v) && (decimals === 0 || decimals === undefined)) {
      return v.toLocaleString("en-US")
    }
    return Number(v).toLocaleString("en-US", {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    })
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

// Category-scale gap: endpoints are more than one index apart, so the
// segment is bridging one or more missing hourly points.
function isGapSegment(ctx) {
  const x0 = ctx.p0?.parsed?.x
  const x1 = ctx.p1?.parsed?.x
  if (x0 == null || x1 == null) return false
  return Math.abs(x1 - x0) > 1
}
