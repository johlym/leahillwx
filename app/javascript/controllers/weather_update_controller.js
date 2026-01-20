import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "temperature",
    "feelsLike",
    "counter",
    "windSpeed",
    "gustSpeed",
    "rainDay",
    "rainRate",
    "dewPoint",
    "humidity",
    "pressure",
    "uv",
    "light"
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
      this.temperatureTarget.textContent = `${parseFloat(data.temperature_f).toFixed(1)}° F`
    }
    
    if (this.hasFeelsLikeTarget) {
      this.feelsLikeTarget.textContent = `(feels like ${parseFloat(data.feels_like_f).toFixed(1)}° F)`
    }
    
    if (this.hasCounterTarget) {
      this.counterTarget.textContent = `No. ${data.counter.toLocaleString()} `
      this.flashCounter()
    }
    
    if (this.hasWindSpeedTarget) {
      this.windSpeedTarget.textContent = `${data.wind_speed_mph} mph ${data.wind_direction_compass}`
    }
    
    if (this.hasGustSpeedTarget) {
      this.gustSpeedTarget.textContent = `Gusting to ${data.gust_speed_mph} mph`
    }
    
    if (this.hasRainDayTarget) {
      this.rainDayTarget.textContent = `${data.rain_day_in} in`
    }
    
    if (this.hasRainRateTarget) {
      this.rainRateTarget.textContent = `(${data.rain_rate_in} in/hr)`
    }
    
    if (this.hasDewPointTarget) {
      this.dewPointTarget.textContent = `${parseFloat(data.dew_point_f).toFixed(1)}° F`
    }
    
    if (this.hasHumidityTarget) {
      this.humidityTarget.textContent = `${data.humidity} %`
    }
    
    if (this.hasPressureTarget) {
      this.pressureTarget.textContent = `${data.barometer_abs_mb} mb`
    }
    
    if (this.hasUvTarget) {
      this.uvTarget.textContent = `${data.uv} W/m2`
    }
    
    if (this.hasLightTarget) {
      this.lightTarget.textContent = `${data.light_lux} lux`
    }
  }

  flashCounter() {
    this.counterTarget.classList.add('counter-flash')
    void this.counterTarget.offsetWidth
    this.counterTarget.classList.remove('counter-flash')
  }
}
