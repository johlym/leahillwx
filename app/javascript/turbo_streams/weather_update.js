import { StreamActions } from "@hotwired/turbo"

StreamActions.weather_update = function() {
  const data = JSON.parse(this.getAttribute("data"))
  const target = document.querySelector(`[data-controller~="weather-update"]`)
  
  if (target) {
    target.dispatchEvent(
      new CustomEvent("weather:update", {
        detail: data,
        bubbles: true
      })
    )
  }
}
