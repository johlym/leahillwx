import { Controller } from "@hotwired/stimulus"

// Writes live weather values into stat cards. Keep units / decimal
// precision identical to Home::CurrentWeather::ConditionsComponent.
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
    this.element.addEventListener("weather:update", this.handleUpdate.bind(this))
  }

  disconnect() {
    this.element.removeEventListener("weather:update", this.handleUpdate.bind(this))
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
  }

  renderSoil(readings) {
    if (!Array.isArray(readings) || readings.length === 0) {
      return `<p class="live-tile-meta">No sensors reporting</p>`
    }

    return readings.map((reading) => {
      const values = []
      if (reading.moisture != null) {
        values.push(
          `<span class="soil-channel-value"><span class="soil-channel-number">${this.asInt(reading.moisture)}</span><span class="soil-channel-unit">%</span></span>`
        )
      }
      if (reading.temperature_f != null) {
        values.push(
          `<span class="soil-channel-value"><span class="soil-channel-number">${this.asInt(reading.temperature_f)}</span><span class="soil-channel-unit">°F</span></span>`
        )
      }

      const name = reading.name || `Ch ${reading.channel}`
      return `<div class="soil-channel">
        <span class="soil-channel-label">${name}</span>
        <div class="soil-channel-values">${values.join("")}</div>
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
