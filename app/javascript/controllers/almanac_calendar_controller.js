import { Controller } from "@hotwired/stimulus"
import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Tooltip,
  Filler,
} from "chart.js"
import { readPaletteColors, withAlpha, observePaletteChanges } from "./helpers/palette"

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Tooltip,
  Filler,
)

// Expandable row on the almanac calendar: on click we reveal a hidden
// row and render an hourly altitude curve for the sun or moon on that
// day using Chart.js against the current time-of-day palette.
export default class extends Controller {
  static targets = ["chevron", "expandedRow", "altitudeChart"]

  connect() {
    this.expandedRows = new Set()
    this.charts = new Map()
    this.paletteObserver = observePaletteChanges(() => this.rethemeCharts())
  }

  disconnect() {
    if (this.paletteObserver) this.paletteObserver.disconnect()
    this.charts.forEach((chart) => chart.destroy())
    this.charts.clear()
  }

  toggleRow(event) {
    const row = event.currentTarget
    const date = row.dataset.almanacCalendarDateValue

    const expandedRow = this.expandedRowTargets.find(
      (target) => target.dataset.almanacCalendarDate === date
    )
    if (!expandedRow) return

    const chevron = row.querySelector('[data-almanac-calendar-target="chevron"]')

    if (this.expandedRows.has(date)) {
      expandedRow.classList.add("hidden")
      if (chevron) chevron.textContent = "+"
      this.expandedRows.delete(date)

      const existing = this.charts.get(date)
      if (existing) {
        existing.destroy()
        this.charts.delete(date)
      }
      const chartContainer = expandedRow.querySelector('[data-almanac-calendar-target="altitudeChart"]')
      if (chartContainer) chartContainer.innerHTML = ""
    } else {
      expandedRow.classList.remove("hidden")
      if (chevron) chevron.textContent = "\u2212"
      this.expandedRows.add(date)
      this.createAltitudeChart(expandedRow, date)
    }
  }

  createAltitudeChart(expandedRow, date) {
    const chartContainer = expandedRow.querySelector('[data-almanac-calendar-target="altitudeChart"]')
    if (!chartContainer) return

    const positionsJson = chartContainer.dataset.positions
    const dateLabel = chartContainer.dataset.date
    const body = chartContainer.dataset.body || "moon"
    if (!positionsJson) return

    let positions
    try {
      positions = JSON.parse(positionsJson)
    } catch (err) {
      console.error("Error parsing almanac positions:", err)
      return
    }

    chartContainer.innerHTML = ""
    const canvas = document.createElement("canvas")
    canvas.setAttribute("role", "img")
    canvas.setAttribute(
      "aria-label",
      `${body === "sun" ? "Sun" : "Moon"} altitude for ${dateLabel}`
    )
    chartContainer.style.height = "260px"
    chartContainer.appendChild(canvas)

    const palette = readPaletteColors()
    const color = body === "sun" ? palette.chartColors[1] : palette.chartColors[0]

    const labels = positions.map((p) => `${String(p.h).padStart(2, "0")}:00`)
    const data = positions.map((p) => p.alt)

    const chart = new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: `${body === "sun" ? "Sun" : "Moon"} altitude`,
            data,
            borderColor: color,
            backgroundColor: withAlpha(color, 0.2),
            fill: true,
            tension: 0.35,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHitRadius: 8,
            spanGaps: true,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: palette.surface2,
            titleColor: palette.textStrong,
            bodyColor: palette.text,
            borderColor: palette.border,
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: (item) => `Altitude: ${item.parsed.y.toFixed(1)}°`,
            },
          },
        },
        scales: {
          x: {
            grid: { color: withAlpha(palette.border, 0.4) },
            border: { color: withAlpha(palette.border, 0.4) },
            ticks: { color: palette.muted, maxRotation: 0, autoSkip: true, autoSkipPadding: 12 },
          },
          y: {
            min: -90,
            max: 90,
            grid: { color: withAlpha(palette.border, 0.4) },
            border: { color: withAlpha(palette.border, 0.4) },
            ticks: {
              color: palette.muted,
              stepSize: 30,
              callback: (v) => `${v}°`,
            },
          },
        },
      },
    })

    this.charts.set(date, chart)
  }

  rethemeCharts() {
    if (this.charts.size === 0) return
    const palette = readPaletteColors()
    this.charts.forEach((chart) => {
      const dataset = chart.data.datasets[0]
      if (dataset) {
        dataset.backgroundColor = withAlpha(dataset.borderColor, 0.2)
      }
      chart.options.plugins.tooltip.backgroundColor = palette.surface2
      chart.options.plugins.tooltip.titleColor = palette.textStrong
      chart.options.plugins.tooltip.bodyColor = palette.text
      chart.options.plugins.tooltip.borderColor = palette.border
      chart.options.scales.x.grid.color = withAlpha(palette.border, 0.4)
      chart.options.scales.x.ticks.color = palette.muted
      chart.options.scales.y.grid.color = withAlpha(palette.border, 0.4)
      chart.options.scales.y.ticks.color = palette.muted
      chart.update("none")
    })
  }
}
