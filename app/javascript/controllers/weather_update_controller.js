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
    "uvi",
    "solarIrradiance",
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
      this.windSpeedTarget.textContent = `${Math.round(data.wind_speed_mph)} mph ${data.wind_direction_compass}`
    }
    
    if (this.hasGustSpeedTarget) {
      this.gustSpeedTarget.textContent = `Gusting to ${Math.round(data.gust_speed_mph)} mph`
    }
    
    if (this.hasRainDayTarget) {
      this.rainDayTarget.textContent = `${Math.round(data.rain_day_in * 100) / 100} in.`
    }
    
    if (this.hasRainRateTarget) {
      this.rainRateTarget.textContent = `${Math.round(data.rain_rate_in * 100) / 100} in./hr`
    }
    
    if (this.hasDewPointTarget) {
      this.dewPointTarget.textContent = `${parseFloat(data.dew_point_f).toFixed(0)}°`
    }
    
    if (this.hasHumidityTarget) {
      this.humidityTarget.textContent = `${data.humidity}%`
    }
    
    if (this.hasPressureTarget) {
      this.pressureTarget.textContent = `${Math.round(data.barometer_abs_mb)}mb`
    }
    
    if (this.hasUviTarget) {
      this.uviTarget.textContent = `${Math.round(data.uvi)}`
    }
    
    if (this.hasSolarIrradianceTarget) {
      this.solarIrradianceTarget.textContent = `${Math.round(data.uv)} W/m²`
    }
    
    if (this.hasLightTarget) {
      this.lightTarget.textContent = `${Math.round(data.light_lux)} lux`
    }
  }

  flashCounter() {
    this.counterTarget.classList.add('counter-flash')
    void this.counterTarget.offsetWidth
    this.counterTarget.classList.remove('counter-flash')
  }
}
