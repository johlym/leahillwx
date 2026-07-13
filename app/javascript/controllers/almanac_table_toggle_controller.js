import { Controller } from "@hotwired/stimulus"

// Toggles between the Sun and Moon tables in the almanac. Reuses the
// `.ui-tabs-tab-active` visual state to stay consistent with the
// rest of the token-driven UI.
export default class extends Controller {
  static targets = ["moonTable", "sunTable", "moonBtn", "sunBtn"]

  connect() {
    this.showSun()
  }

  showMoon() {
    this.moonTableTarget.classList.remove("hidden")
    this.sunTableTarget.classList.add("hidden")
    this.setActive(this.moonBtnTarget, true)
    this.setActive(this.sunBtnTarget, false)
  }

  showSun() {
    this.sunTableTarget.classList.remove("hidden")
    this.moonTableTarget.classList.add("hidden")
    this.setActive(this.sunBtnTarget, true)
    this.setActive(this.moonBtnTarget, false)
  }

  setActive(button, active) {
    button.classList.toggle("ui-tabs-tab-active", active)
    button.setAttribute("aria-selected", active ? "true" : "false")
  }
}
