import { Controller } from "@hotwired/stimulus"
import {
  applyConnectionBadge,
  isCableStreamOpen,
  resolveConnectionStatus,
  STATUS_LIVE,
} from "./helpers/connection_status"

export default class extends Controller {
  static targets = ["badge", "label"]
  static values = { hasReading: { type: Boolean, default: false } }

  connect() {
    this.boundCheck = this.checkConnection.bind(this)
    this.checkConnection()
    this.checkInterval = setInterval(this.boundCheck, 2000)
    document.addEventListener("turbo:load", this.boundCheck)
  }

  disconnect() {
    if (this.checkInterval) {
      clearInterval(this.checkInterval)
    }
    document.removeEventListener("turbo:load", this.boundCheck)
    document.documentElement.classList.remove("is-live")
  }

  checkConnection() {
    const streamSource = document.querySelector("turbo-cable-stream-source")
    const status = resolveConnectionStatus({
      streamOpen: isCableStreamOpen(streamSource),
      hasLastUpdated: this.hasLastUpdated(),
    })
    this.updateBadge(status)
  }

  hasLastUpdated() {
    if (this.hasReadingValue) return true
    return Boolean(document.querySelector("[data-weather-update-target='timestamp']"))
  }

  updateBadge(status) {
    document.documentElement.classList.toggle("is-live", status === STATUS_LIVE)
    if (!this.hasBadgeTarget) return
    applyConnectionBadge(
      this.badgeTarget,
      this.hasLabelTarget ? this.labelTarget : null,
      status,
    )
  }
}
