import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["forecast8h", "forecast12h", "forecast16h"]
  static classes = ["forecastHidden"]

  connect() {
    this.showView("8h")
  }

  toggle(event) {
    const view = event.currentTarget.dataset.view
    this.showView(view)
  }

  showView(view) {
    this.forecast8hTarget.classList.toggle(this.forecastHiddenClass, view !== "8h")
    this.forecast12hTarget.classList.toggle(this.forecastHiddenClass, view !== "12h")
    this.forecast16hTarget.classList.toggle(this.forecastHiddenClass, view !== "16h")
  }
}
