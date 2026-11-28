import { Controller } from "@hotwired/stimulus"
import {
  DEFAULT_INTERVAL_MS,
  FADE_MS,
  countdownSeconds,
  ringDashOffset,
  slideAnnouncement,
  wrapIndex,
} from "./helpers/tv_cycle"

export default class extends Controller {
  static targets = ["slide", "count", "ring", "status", "toggle"]
  static values = {
    interval: { type: Number, default: DEFAULT_INTERVAL_MS }
  }

  connect() {
    this.index = this.slideTargets.findIndex((slide) => slide.classList.contains("is-active"))
    if (this.index < 0) this.index = 0
    this.paused = false
    this.remaining = this.intervalValue
    this.reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    this.element.style.setProperty("--tv-fade", `${FADE_MS}ms`)
    this.onKeydown = (event) => this.keydown(event)
    this.onVisibility = () => {
      this.lastTick = performance.now()
      if (!document.hidden) this.requestWakeLock()
    }
    window.addEventListener("keydown", this.onKeydown)
    document.addEventListener("visibilitychange", this.onVisibility)
    this.applySlide({ animate: false, announce: false })
    this.renderProgress()
    this.lastTick = performance.now()
    this.frame = window.requestAnimationFrame((now) => this.tick(now))
    this.requestWakeLock()
  }

  disconnect() {
    window.cancelAnimationFrame(this.frame)
    window.removeEventListener("keydown", this.onKeydown)
    document.removeEventListener("visibilitychange", this.onVisibility)
    this.clearLeaveTimer()
    this.wakeLock?.release?.().catch(() => {})
  }

  tick(now) {
    this.frame = window.requestAnimationFrame((next) => this.tick(next))
    const elapsed = now - this.lastTick
    this.lastTick = now
    if (this.paused || document.hidden) return

    this.remaining -= elapsed
    if (this.remaining <= 0) {
      this.advance(1, { announce: false })
      return
    }
    this.renderProgress()
  }

  advance(delta, { announce = false } = {}) {
    if (this.slideTargets.length === 0) return
    this.index = wrapIndex(this.index + delta, this.slideTargets.length)
    this.remaining = this.intervalValue
    this.applySlide({ animate: true, announce })
    this.renderProgress()
  }

  togglePause() {
    this.paused = !this.paused
    if (this.hasToggleTarget) {
      this.toggleTarget.classList.toggle("is-paused", this.paused)
      this.toggleTarget.setAttribute("aria-pressed", this.paused ? "true" : "false")
    }
    this.announce(this.paused ? "Rotation paused" : "Rotation resumed")
  }

  keydown(event) {
    if (event.repeat || event.metaKey || event.ctrlKey || event.altKey) return
    const target = event.target
    if (
      target instanceof HTMLInputElement ||
      target instanceof HTMLTextAreaElement ||
      target instanceof HTMLSelectElement ||
      target?.isContentEditable
    ) return

    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.advance(1, { announce: true })
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.advance(-1, { announce: true })
    }
  }

  applySlide({ animate, announce }) {
    const previous = this.slideTargets.findIndex((slide) => slide.classList.contains("is-active"))
    const motion = animate && !this.reduceMotion
    this.clearLeaveTimer()
    this.slideTargets.forEach((slide) => slide.classList.remove("is-leaving"))

    this.slideTargets.forEach((slide, i) => {
      const active = i === this.index
      if (motion && i === previous && !active) slide.classList.add("is-leaving")
      slide.classList.toggle("is-active", active)
      if (active) {
        slide.removeAttribute("inert")
        slide.setAttribute("aria-hidden", "false")
      } else {
        slide.setAttribute("inert", "")
        slide.setAttribute("aria-hidden", "true")
      }
    })

    if (motion) {
      this.element.classList.add("is-animate")
      this.leaveTimer = window.setTimeout(() => {
        this.slideTargets.forEach((slide) => slide.classList.remove("is-leaving"))
      }, FADE_MS)
    }

    if (announce) {
      const slide = this.slideTargets[this.index]
      const label = slide?.dataset.tvLabel || "Screen"
      this.announce(slideAnnouncement(label, this.index, this.slideTargets.length))
    }
  }

  renderProgress() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = String(countdownSeconds(this.remaining))
    }
    if (this.hasRingTarget) {
      this.ringTarget.style.strokeDashoffset = String(ringDashOffset(this.remaining, this.intervalValue))
    }
  }

  announce(message) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = ""
    window.requestAnimationFrame(() => {
      this.statusTarget.textContent = message
    })
  }

  clearLeaveTimer() {
    if (!this.leaveTimer) return
    window.clearTimeout(this.leaveTimer)
    this.leaveTimer = null
  }

  requestWakeLock() {
    const lock = navigator.wakeLock
    if (!lock?.request) return
    lock.request("screen").then((sentinel) => {
      this.wakeLock = sentinel
    }).catch(() => {
      this.wakeLock = null
    })
  }
}
