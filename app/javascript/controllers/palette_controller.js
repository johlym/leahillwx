import { Controller } from "@hotwired/stimulus"

// Manages the time-of-day palette on <html data-palette="...">.
// The server sets the initial palette so first paint is correct; this
// controller schedules a single timer for the next boundary transition
// (sunrise / noon / sunset - 1h / sunset + 10m) and swaps the attribute
// when we hit it. It re-computes future boundaries locally from
// data-palette-sunrise-value / data-palette-sunset-value so a page can
// stay open across an entire day without needing to reload.
//
// Values expected (ISO 8601 strings for the day currently displayed):
//   data-palette-sunrise-value
//   data-palette-sunset-value
//   data-palette-next-transition-at-value   (optional, seeds first flip)
export default class extends Controller {
  static values = {
    sunrise: String,
    sunset: String,
    nextTransitionAt: String,
  }

  connect() {
    this.scheduleNext()
  }

  disconnect() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  scheduleNext() {
    const nextAt = this.computeNextTransitionAt(new Date())
    if (!nextAt) return

    const delay = Math.max(1000, nextAt.getTime() - Date.now())
    if (this.timer) clearTimeout(this.timer)
    this.timer = setTimeout(() => this.applyPaletteAt(nextAt), delay)
  }

  applyPaletteAt(when) {
    const palette = this.paletteFor(when)
    if (palette) {
      this.element.setAttribute("data-palette", palette)
    }
    this.scheduleNext()
  }

  paletteFor(when) {
    const boundaries = this.dayBoundaries(when)
    if (!boundaries) return null

    const { sunrise, noon, sunsetMinus1h, sunsetPlus10m } = boundaries
    if (when < sunrise) return "night"
    if (when < noon) return "sunrise"
    if (when < sunsetMinus1h) return "midday"
    if (when < sunsetPlus10m) return "sunset"
    return "night"
  }

  computeNextTransitionAt(from) {
    // Prefer the server-provided seed if it's still in the future.
    if (this.hasNextTransitionAtValue && this.nextTransitionAtValue) {
      const seed = new Date(this.nextTransitionAtValue)
      if (!Number.isNaN(seed.getTime()) && seed > from) return seed
    }

    const today = this.dayBoundaries(from)
    if (today) {
      for (const key of ["sunrise", "noon", "sunsetMinus1h", "sunsetPlus10m"]) {
        if (today[key] > from) return today[key]
      }
    }

    // All of today's boundaries have passed -> approximate tomorrow's
    // sunrise as +24h from the seed sunrise. Good enough; the next tick
    // will re-resolve using fresh data if the page reloads.
    if (today && today.sunrise) {
      const tomorrow = new Date(today.sunrise.getTime() + 24 * 3600 * 1000)
      return tomorrow
    }
    return null
  }

  dayBoundaries(reference) {
    if (!this.hasSunriseValue || !this.hasSunsetValue) return null
    const sunrise = new Date(this.sunriseValue)
    const sunset = new Date(this.sunsetValue)
    if (Number.isNaN(sunrise.getTime()) || Number.isNaN(sunset.getTime())) return null

    // Noon in the seeded day's local wall clock, using the same date as
    // the sunrise seed to avoid timezone drift on the client.
    const noon = new Date(sunrise)
    noon.setHours(12, 0, 0, 0)

    return {
      sunrise,
      noon,
      sunsetMinus1h: new Date(sunset.getTime() - 60 * 60 * 1000),
      sunsetPlus10m: new Date(sunset.getTime() + 10 * 60 * 1000),
    }
  }
}
