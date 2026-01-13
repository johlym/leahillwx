import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["countdown"]
  static values = {
    interval: { type: Number, default: 60000 }
  }

  connect() {
    this.secondsRemaining = this.intervalValue / 1000
    this.updateCountdown()
    this.startRefreshing()
    this.startCountdown()
  }

  disconnect() {
    this.stopRefreshing()
    this.stopCountdown()
  }

  startRefreshing() {
    this.refreshInterval = setInterval(() => {
      this.refreshImages()
      this.secondsRemaining = this.intervalValue / 1000
    }, this.intervalValue)
  }

  stopRefreshing() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
    }
  }

  startCountdown() {
    this.countdownInterval = setInterval(() => {
      this.secondsRemaining--
      if (this.secondsRemaining < 0) {
        this.secondsRemaining = this.intervalValue / 1000
      }
      this.updateCountdown()
    }, 1000)
  }

  stopCountdown() {
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval)
    }
  }

  updateCountdown() {
    if (this.hasCountdownTarget) {
      this.countdownTarget.textContent = this.secondsRemaining
    }
  }

  refreshImages() {
    const images = this.element.querySelectorAll('img')
    const timestamp = new Date().getTime()
    
    images.forEach(img => {
      const currentSrc = img.src.split('?')[0]
      img.src = `${currentSrc}?t=${timestamp}`
    })
  }
}
