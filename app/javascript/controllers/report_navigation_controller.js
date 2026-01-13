import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["yearSelect", "monthSelect", "goButton", "message", "form"]
  
  connect() {
    this.loadAvailableReports()
  }
  
  async loadAvailableReports() {
    try {
      const response = await fetch("/reports/available.json")
      const data = await response.json()
      
      if (Object.keys(data).length === 0) {
        this.showMessage("No reports available yet.")
        return
      }
      
      this.availableReports = data
      this.populateYears()
      
      // Set current selections if provided
      const currentYear = this.yearSelectTarget.dataset.currentYear
      const currentMonth = this.yearSelectTarget.dataset.currentMonth
      
      if (currentYear && currentMonth) {
        this.yearSelectTarget.value = currentYear
        this.updateMonths()
        
        // Select the current month by name
        const monthName = this.getMonthName(parseInt(currentMonth))
        this.monthSelectTarget.value = monthName
        this.goButtonTarget.disabled = false
      }
    } catch (error) {
      console.error("Error loading reports:", error)
      this.showMessage("Error loading available reports.")
    }
  }
  
  populateYears() {
    const years = Object.keys(this.availableReports).sort((a, b) => b - a)
    
    years.forEach(year => {
      const option = document.createElement("option")
      option.value = year
      option.textContent = year
      this.yearSelectTarget.appendChild(option)
    })
  }
  
  updateMonths() {
    const selectedYear = this.yearSelectTarget.value
    
    // Clear and disable month select
    this.monthSelectTarget.innerHTML = '<option value="">Select a Month</option>'
    this.monthSelectTarget.disabled = true
    this.goButtonTarget.disabled = true
    
    if (!selectedYear) {
      return
    }
    
    // Populate months for selected year
    const months = this.availableReports[selectedYear] || []
    
    if (months.length === 0) {
      this.showMessage("No reports available for this year.")
      return
    }
    
    months.forEach(monthName => {
      const option = document.createElement("option")
      option.value = monthName
      option.textContent = this.capitalize(monthName)
      this.monthSelectTarget.appendChild(option)
    })
    
    this.monthSelectTarget.disabled = false
    this.clearMessage()
  }
  
  navigateToReport() {
    const year = this.yearSelectTarget.value
    const month = this.monthSelectTarget.value
    
    if (!year || !month) {
      this.showMessage("Please select both year and month.")
      return
    }
    
    window.location.href = `/reports/${year}/${month}`
  }
  
  getMonthName(monthNumber) {
    const months = [
      "january", "february", "march", "april", "may", "june",
      "july", "august", "september", "october", "november", "december"
    ]
    return months[monthNumber - 1]
  }
  
  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }
  
  showMessage(message) {
    this.messageTarget.textContent = message
    this.messageTarget.style.display = "block"
  }
  
  clearMessage() {
    this.messageTarget.textContent = ""
    this.messageTarget.style.display = "none"
  }
}
