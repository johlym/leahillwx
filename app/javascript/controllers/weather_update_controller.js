import { Controller } from "@hotwired/stimulus"

// Writes live weather values into stat cards. Each target receives a
// raw *number/text only* — the units live in the surrounding HTML so
// the JS can't accidentally double-print them.
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
      this.temperatureTarget.textContent = `${parseFloat(data.temperature_f).toFixed(0)}°`
    }
    if (this.hasFeelsLikeTarget) {
      this.feelsLikeTarget.textContent = `Feels like ${parseFloat(data.feels_like_f).toFixed(0)}°`
    }
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = data.counter.toLocaleString()
      this.flashCounter()
    }
    if (this.hasWindSpeedTarget) {
      this.windSpeedTarget.textContent = Math.round(data.wind_speed_mph)
    }
    if (this.hasWindDirectionTarget) {
      this.windDirectionTarget.textContent = data.wind_direction_compass
    }
    if (this.hasWindCompassTarget && typeof data.wind_direction_deg === "number") {
      const needle = this.windCompassTarget.querySelector(".compass__needle")
      if (needle) needle.setAttribute("transform", `rotate(${data.wind_direction_deg} 50 50)`)
    }
    if (this.hasGustSpeedTarget) {
      this.gustSpeedTarget.textContent = `Gusting to ${Math.round(data.gust_speed_mph)} mph`
    }
    if (this.hasRainDayTarget) {
      this.rainDayTarget.textContent = (Math.round(data.rain_day_in * 100) / 100).toFixed(2)
    }
    if (this.hasRainRateTarget) {
      this.rainRateTarget.textContent = (Math.round(data.rain_rate_in * 100) / 100).toFixed(2)
    }
    if (this.hasDewPointTarget) {
      this.dewPointTarget.textContent = parseFloat(data.dew_point_f).toFixed(0)
    }
    if (this.hasHumidityTarget) {
      this.humidityTarget.textContent = data.humidity
    }
    if (this.hasPressureTarget) {
      this.pressureTarget.textContent = Math.round(data.barometer_abs_mb)
    }
    if (this.hasUviTarget) {
      this.uviTarget.textContent = Math.round(data.uvi)
    }
    if (this.hasSolarIrradianceTarget) {
      this.solarIrradianceTarget.textContent = Math.round(data.uv)
    }
    if (this.hasLightTarget) {
      this.lightTarget.textContent = Math.round(data.light_lux)
    }
    if (this.hasTimestampTarget) {
      this.timestampTarget.textContent = this.formattedTimestamp()
    }
  }

  formattedTimestamp() {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Los_Angeles",
      month: "long",
      day: "2-digit",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      hour12: true,
    }).formatToParts(new Date())
    const get = (type) => parts.find((p) => p.type === type)?.value || ""
    return `${get("month")} ${get("day")}, ${get("year")} \u2022 ${get("hour")}:${get("minute")} ${get("dayPeriod")}`
  }

  flashCounter() {
    this.counterTarget.classList.add("counter-flash")
    void this.counterTarget.offsetWidth
    this.counterTarget.classList.remove("counter-flash")
  }
}
