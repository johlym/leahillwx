import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["badge"]

  connect() {
    this.checkConnection()
    this.checkInterval = setInterval(() => this.checkConnection(), 2000)
  }

  disconnect() {
    if (this.checkInterval) {
      clearInterval(this.checkInterval)
    }
  }

  checkConnection() {
    const streamSource = document.querySelector("turbo-cable-stream-source")
    const isConnected = streamSource && streamSource.subscription && streamSource.subscription.consumer.connection.isOpen()
    this.updateBadge(isConnected)
  }

  updateBadge(isConnected) {
    if (this.hasBadgeTarget) {
      this.badgeTarget.classList.toggle("hidden", !isConnected)
    }
  }
}
