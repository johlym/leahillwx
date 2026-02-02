import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  navigate(event) {
    const year = document.getElementById('year-select').value
    const month = document.getElementById('month-select').value
    window.location.href = `/almanac/${year}/${month}`
  }

  changeMonth(event) {
    // Auto-navigate on month change
    this.navigate()
  }

  changeYear(event) {
    // Could auto-navigate or wait for button click
    // For now, wait for button click
  }
}
