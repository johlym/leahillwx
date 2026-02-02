import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["moonTable", "sunTable", "moonBtn", "sunBtn"]
  
  connect() {
    // Default to sun table
    this.showSun()
  }

  showMoon() {
    this.moonTableTarget.classList.remove('hidden')
    this.sunTableTarget.classList.add('hidden')
    
    this.moonBtnTarget.classList.add('active-tab')
    this.moonBtnTarget.classList.remove('inactive-tab')
    
    this.sunBtnTarget.classList.remove('active-tab')
    this.sunBtnTarget.classList.add('inactive-tab')
  }

  showSun() {
    this.sunTableTarget.classList.remove('hidden')
    this.moonTableTarget.classList.add('hidden')
    
    this.sunBtnTarget.classList.add('active-tab')
    this.sunBtnTarget.classList.remove('inactive-tab')
    
    this.moonBtnTarget.classList.remove('active-tab')
    this.moonBtnTarget.classList.add('inactive-tab')
  }
}
