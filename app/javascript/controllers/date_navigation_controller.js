import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["yearSelect", "monthSelect", "daySelect", "goButton", "message", "form"]
  
  connect() {
    this.basePath = this.element.dataset.basePath
    this.dayRequired = this.element.dataset.dayRequired === "true"
    this.loadAvailableData()
  }
  
  async loadAvailableData() {
    try {
      const response = await fetch(`${this.basePath}/available.json`)
      const data = await response.json()
      
      if (Object.keys(data).length === 0) {
        this.showMessage("No data available yet.")
        return
      }
      
      this.availableData = data
      this.populateYears()
      
      // Set current selections if provided
      const currentYear = this.yearSelectTarget.dataset.currentYear
      const currentMonth = this.yearSelectTarget.dataset.currentMonth
      const currentDay = this.daySelectTarget.dataset.currentDay
      
      if (currentYear && currentMonth) {
        this.yearSelectTarget.value = currentYear
        this.updateMonths()
        
        // Select the current month by name
        const monthName = this.getMonthName(parseInt(currentMonth))
        this.monthSelectTarget.value = monthName
        this.updateDays()
        
        // Select the current day if provided
        if (currentDay) {
          this.daySelectTarget.value = currentDay
        }
        
        this.goButtonTarget.disabled = false
      }
    } catch (error) {
      console.error("Error loading data:", error)
      this.showMessage("Error loading available data.")
    }
  }
  
  populateYears() {
    const years = Object.keys(this.availableData).sort().reverse()
    
    years.forEach(year => {
      const option = document.createElement("option")
      option.value = year
      option.textContent = year
      this.yearSelectTarget.appendChild(option)
    })
  }
  
  updateMonths() {
    const selectedYear = this.yearSelectTarget.value
    
    // Clear and disable dependent selects
    this.monthSelectTarget.innerHTML = '<option value="">Select a Month</option>'
    this.daySelectTarget.innerHTML = '<option value="">Select a Day</option>'
    this.daySelectTarget.disabled = true
    this.goButtonTarget.disabled = true
    
    if (!selectedYear) {
      this.monthSelectTarget.disabled = true
      return
    }
    
    const months = this.availableData[selectedYear]
    if (!months || Object.keys(months).length === 0) {
      this.monthSelectTarget.disabled = true
      this.showMessage("No data available for this year.")
      return
    }
    
    // Populate months in calendar order
    const monthOrder = ["january", "february", "march", "april", "may", "june",
                       "july", "august", "september", "october", "november", "december"]
    
    monthOrder.forEach(monthName => {
      if (months[monthName]) {
        const option = document.createElement("option")
        option.value = monthName
        option.textContent = this.capitalizeMonth(monthName)
        this.monthSelectTarget.appendChild(option)
      }
    })
    
    this.monthSelectTarget.disabled = false
    this.clearMessage()
  }
  
  updateDays() {
    const selectedYear = this.yearSelectTarget.value
    const selectedMonth = this.monthSelectTarget.value
    
    // Clear and disable day select
    this.daySelectTarget.innerHTML = '<option value="">Select a Day</option>'
    this.goButtonTarget.disabled = true
    
    if (!selectedYear || !selectedMonth) {
      this.daySelectTarget.disabled = true
      return
    }
    
    const days = this.availableData[selectedYear][selectedMonth]
    if (!days || days.length === 0) {
      this.daySelectTarget.disabled = true
      this.showMessage("No data available for this month.")
      return
    }
    
    // Populate days
    days.forEach(dayInfo => {
      const day = dayInfo.day
      const option = document.createElement("option")
      option.value = day
      option.textContent = day
      this.daySelectTarget.appendChild(option)
    })
    
    this.daySelectTarget.disabled = false
    this.clearMessage()
    this.enableGoButton()
  }
  
  enableGoButton() {
    const year = this.yearSelectTarget.value
    const month = this.monthSelectTarget.value
    const day = this.daySelectTarget.value
    
    // If day is required, all three must be selected
    // If day is optional, only year and month are required
    if (this.dayRequired) {
      this.goButtonTarget.disabled = !(year && month && day)
    } else {
      this.goButtonTarget.disabled = !(year && month)
    }
  }
  
  navigateToDate() {
    const year = this.yearSelectTarget.value
    const month = this.monthSelectTarget.value
    const day = this.daySelectTarget.value
    
    if (!year || !month) {
      this.showMessage("Please select a year and month.")
      return
    }
    
    if (this.dayRequired && !day) {
      this.showMessage("Please select a day.")
      return
    }
    
    // Navigate to the selected date
    if (day) {
      window.location.href = `${this.basePath}/${year}/${month}/${day}`
    } else {
      window.location.href = `${this.basePath}/${year}/${month}`
    }
  }
  
  getMonthName(monthNumber) {
    const months = ["january", "february", "march", "april", "may", "june",
                   "july", "august", "september", "october", "november", "december"]
    return months[monthNumber - 1]
  }
  
  capitalizeMonth(month) {
    return month.charAt(0).toUpperCase() + month.slice(1)
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
