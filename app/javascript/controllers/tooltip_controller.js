import { Controller } from "@hotwired/stimulus"

// Lightweight floating tooltip. Attach to any element with:
//
//   <button data-controller="tooltip"
//           data-tooltip-title-value="Aug 14"
//           data-tooltip-body-value="High 92°F · Low 61°F">…</button>
//
// The tooltip is a single detached div reused across the page. It
// positions itself above the anchor and flips below when there isn't
// room. Dismisses on mouseleave/blur/Escape/scroll.
export default class extends Controller {
  static values = {
    title: String,
    body: String,
    placement: { type: String, default: "top" },
  }

  static tip = null
  static rafHandle = null

  connect() {
    this.showBound = this.show.bind(this)
    this.hideBound = this.hide.bind(this)
    this.escBound = this.onEscape.bind(this)

    this.element.addEventListener("mouseenter", this.showBound)
    this.element.addEventListener("focus", this.showBound)
    this.element.addEventListener("mouseleave", this.hideBound)
    this.element.addEventListener("blur", this.hideBound)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.showBound)
    this.element.removeEventListener("focus", this.showBound)
    this.element.removeEventListener("mouseleave", this.hideBound)
    this.element.removeEventListener("blur", this.hideBound)
    if (this.isOwner()) this.hide()
  }

  show() {
    const tip = this.ensureTip()
    tip.innerHTML = ""
    if (this.hasTitleValue && this.titleValue) {
      const t = document.createElement("div")
      t.className = "app-tooltip__title"
      t.textContent = this.titleValue
      tip.appendChild(t)
    }
    if (this.hasBodyValue && this.bodyValue) {
      const b = document.createElement("div")
      b.className = "app-tooltip__body"
      b.textContent = this.bodyValue
      tip.appendChild(b)
    }
    tip.dataset.owner = this.uniqueId()
    tip.dataset.placement = this.placementValue
    tip.style.opacity = "0"
    tip.classList.add("app-tooltip--visible")
    this.reposition()
    // Reveal after position is set to avoid a flash at (0,0).
    requestAnimationFrame(() => (tip.style.opacity = "1"))
    document.addEventListener("keydown", this.escBound)
    window.addEventListener("scroll", this.hideBound, { passive: true, capture: true })
    window.addEventListener("resize", this.hideBound, { passive: true })
  }

  hide() {
    const tip = this.constructor.tip
    if (!tip) return
    if (this.isOwner()) {
      tip.classList.remove("app-tooltip--visible")
      tip.style.opacity = "0"
      delete tip.dataset.owner
    }
    document.removeEventListener("keydown", this.escBound)
    window.removeEventListener("scroll", this.hideBound, { capture: true })
    window.removeEventListener("resize", this.hideBound)
  }

  onEscape(event) {
    if (event.key === "Escape") this.hide()
  }

  reposition() {
    const tip = this.constructor.tip
    if (!tip || !this.isOwner()) return
    const anchor = this.element.getBoundingClientRect()
    const tipRect = tip.getBoundingClientRect()
    const margin = 8

    let placement = this.placementValue
    let top =
      placement === "bottom"
        ? anchor.bottom + margin
        : anchor.top - tipRect.height - margin
    let left = anchor.left + anchor.width / 2 - tipRect.width / 2

    // Flip if we'd overflow the viewport vertically.
    if (top < 4) {
      placement = "bottom"
      top = anchor.bottom + margin
    }
    if (top + tipRect.height > window.innerHeight - 4) {
      placement = "top"
      top = anchor.top - tipRect.height - margin
    }
    // Clamp horizontally.
    const maxLeft = window.innerWidth - tipRect.width - 4
    if (left < 4) left = 4
    if (left > maxLeft) left = maxLeft

    tip.dataset.placement = placement
    tip.style.transform = `translate3d(${Math.round(left)}px, ${Math.round(top)}px, 0)`
  }

  ensureTip() {
    if (this.constructor.tip && this.constructor.tip.isConnected) return this.constructor.tip
    const tip = document.createElement("div")
    tip.className = "app-tooltip"
    tip.setAttribute("role", "tooltip")
    document.body.appendChild(tip)
    this.constructor.tip = tip
    return tip
  }

  isOwner() {
    return this.constructor.tip && this.constructor.tip.dataset.owner === this.uniqueId()
  }

  uniqueId() {
    if (!this._uid) {
      this._uid = `tip-${Math.random().toString(36).slice(2, 10)}`
    }
    return this._uid
  }
}
