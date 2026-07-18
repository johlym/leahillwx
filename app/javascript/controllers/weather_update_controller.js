import { Controller } from "@hotwired/stimulus"

// Writes live weather values into stat cards. Keep units / decimal
// precision identical to Home::CurrentWeather::ConditionsComponent.
// Also refreshes live-tile sparklines when the broadcast includes series.
export default class extends Controller {
  static targets = [
    "timestamp",
    "temperature",
    "feelsLike",
    "counter",
    "windSpeed",
    "windDirection",
    "windCompass",
    "gustSpeed",
    "rainDay",
    "rainRate",
    "dewPoint",
    "humidity",
    "pressure",
    "uvi",
    "solarIrradiance",
    "light",
    "soil",
  ]

  connect() {
    this.boundHandleUpdate = this.handleUpdate.bind(this)
    this.element.addEventListener("weather:update", this.boundHandleUpdate)
  }

  disconnect() {
    this.element.removeEventListener("weather:update", this.boundHandleUpdate)
  }

  handleUpdate(event) {
    this.updateWeatherData(event.detail)
  }

  updateWeatherData(data) {
    if (this.hasTemperatureTarget) {
      this.temperatureTarget.textContent = `${this.asInt(data.temperature_f)}°F`
    }
    if (this.hasFeelsLikeTarget) {
      this.feelsLikeTarget.textContent = `Feels like ${this.asInt(data.feels_like_f)}°F`
    }
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = data.counter.toLocaleString()
      this.flashCounter()
    }
    if (this.hasWindSpeedTarget) {
      this.windSpeedTarget.textContent = this.asInt(data.wind_speed_mph)
    }
    if (this.hasWindDirectionTarget) {
      this.windDirectionTarget.textContent = data.wind_direction_compass
    }
    if (this.hasWindCompassTarget && typeof data.wind_direction_deg === "number") {
      const needle = this.windCompassTarget.querySelector(".compass__needle")
      if (needle) needle.style.setProperty("--compass-needle-deg", `${data.wind_direction_deg}deg`)
    }
    if (this.hasGustSpeedTarget) {
      this.gustSpeedTarget.textContent = `Gusting to ${this.asInt(data.gust_speed_mph)} mph`
    }
    if (this.hasRainDayTarget) {
      this.rainDayTarget.textContent = this.asFixed2(data.rain_day_in)
    }
    if (this.hasRainRateTarget) {
      this.rainRateTarget.textContent = this.asFixed2(data.rain_rate_in)
    }
    if (this.hasDewPointTarget) {
      this.dewPointTarget.textContent = this.asInt(data.dew_point_f)
    }
    if (this.hasHumidityTarget) {
      this.humidityTarget.textContent = this.asInt(data.humidity)
    }
    if (this.hasPressureTarget) {
      this.pressureTarget.textContent = this.asInt(data.barometer_abs_mb)
    }
    if (this.hasUviTarget) {
      this.uviTarget.textContent = this.asInt(data.uvi)
    }
    if (this.hasSolarIrradianceTarget) {
      this.solarIrradianceTarget.textContent = this.asInt(data.uv)
    }
    if (this.hasLightTarget) {
      this.lightTarget.textContent = this.asInt(data.light_lux)
    }
    if (this.hasTimestampTarget) {
      this.timestampTarget.textContent = this.formattedTimestamp()
    }
    if (this.hasSoilTarget) {
      this.soilTarget.innerHTML = this.renderSoil(data.soil || [])
    }
    if (data.sparklines) {
      this.updateSparklines(data.sparklines)
    }
  }

  updateSparklines(sparklines) {
    document.querySelectorAll("[data-live-sparkline]").forEach((el) => {
      const metric = el.dataset.liveSparkline
      const series = sparklines[metric]
      if (!series) return

      const decimals = Number(el.dataset.liveSparklineDecimals || 0)
      const yUnit = el.dataset.liveSparklineYUnit || ""
      const chartData = this.sparklineChartData(series)
      const chartOptions = this.sparklineChartOptions(series, { decimals, yUnit })

      const chartController = this.application.getControllerForElementAndIdentifier(el, "chart")
      if (chartController) {
        chartController.dataValue = chartData
        chartController.optionsValue = chartOptions
      } else {
        el.setAttribute("data-chart-data-value", JSON.stringify(chartData))
        el.setAttribute("data-chart-options-value", JSON.stringify(chartOptions))
      }
    })
  }

  sparklineChartData(series) {
    const datasets = [
      {
        label: "Average",
        data: series.values || [],
        color: "var(--accent)",
        borderWidth: 1.6,
        tension: 0.35,
        spanGaps: true,
        fill: true,
        fillAlpha: 0.12,
      },
    ]

    if (Array.isArray(series.markers)) {
      datasets.push({
        label: "Gust",
        data: series.markers,
        color: "var(--accent)",
        colorAlpha: 0.75,
        borderWidth: 1.4,
        tension: 0.35,
        dashed: true,
        fill: false,
        spanGaps: true,
        pointRadius: 0,
      })
    }

    return {
      labels: series.labels || [],
      datasets,
    }
  }

  sparklineChartOptions(series, { decimals, yUnit }) {
    const options = {
      hideLegend: true,
      hideGrid: true,
      hideXAxis: true,
      yTicks: "minmax",
      tooltipFormat: "hourValue",
      styleGaps: true,
      livePulse: true,
      decimals,
      yUnit,
    }
    if (series.y_min != null) options.yMin = series.y_min
    if (series.y_max != null) options.yMax = series.y_max
    return options
  }

  renderSoil(readings) {
    if (!Array.isArray(readings) || readings.length === 0) {
      return `<p class="live-tile-meta">No sensors reporting</p>`
    }

    return readings.map((reading) => {
      const name = reading.name || `Ch ${reading.channel}`
      const moisture = reading.moisture != null
        ? `<span class="soil-channel-number">${this.asInt(reading.moisture)}</span><span class="soil-channel-unit">%</span>`
        : `<span class="soil-channel-na">N/A</span>`
      const temperature = reading.temperature_f != null
        ? `<span class="soil-channel-number">${this.asInt(reading.temperature_f)}</span><span class="soil-channel-unit">°F</span>`
        : `<span class="soil-channel-na">N/A</span>`
      const battery = reading.battery != null
        ? `<span class="soil-channel-number soil-channel-battery-number">${this.asFixed2(reading.battery)}</span><span class="soil-channel-unit">V</span>`
        : `<span class="soil-channel-na">N/A</span>`

      return `<div class="soil-channel">
        <span class="soil-channel-name">${name}</span>
        <span class="soil-channel-value">${moisture}</span>
        <span class="soil-channel-value">${temperature}</span>
        <span class="soil-channel-value">${battery}</span>
      </div>`
    }).join("")
  }

  asInt(value) {
    return Math.round(parseFloat(value)).toString()
  }

  asFixed2(value) {
    return (Math.round(parseFloat(value) * 100) / 100).toFixed(2)
  }

  formattedTimestamp() {
    // Match ConditionsComponent#reading_timestamp:
    // "Jul 13, 2026 @ 9:24 PM"
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Los_Angeles",
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    }).formatToParts(new Date())
    const get = (type) => parts.find((p) => p.type === type)?.value || ""
    return `${get("month")} ${get("day")}, ${get("year")} @ ${get("hour")}:${get("minute")} ${get("dayPeriod")}`
  }

  flashCounter() {
    this.counterTarget.classList.add("counter-flash")
    void this.counterTarget.offsetWidth
    this.counterTarget.classList.remove("counter-flash")
  }
}
