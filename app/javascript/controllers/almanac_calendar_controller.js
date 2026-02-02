import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static targets = ["chevron", "expandedRow", "altitudeChart"]
  
  connect() {
    this.expandedRows = new Set()
  }

  toggleRow(event) {
    const row = event.currentTarget
    const date = row.dataset.almanacCalendarDateValue
    
    // Find the expanded row
    const expandedRow = this.expandedRowTargets.find(
      target => target.dataset.almanacCalendarDate === date
    )
    
    if (!expandedRow) return

    // Find the chevron in this row
    const chevron = row.querySelector('[data-almanac-calendar-target="chevron"]')
    
    if (this.expandedRows.has(date)) {
      // Collapse
      expandedRow.classList.add('hidden')
      if (chevron) chevron.textContent = '+'
      this.expandedRows.delete(date)
      
      // Clear chart
      const chartContainer = expandedRow.querySelector('[data-almanac-calendar-target="altitudeChart"]')
      if (chartContainer) {
        chartContainer.innerHTML = ''
      }
    } else {
      // Expand
      expandedRow.classList.remove('hidden')
      if (chevron) chevron.textContent = '-'
      this.expandedRows.add(date)
      
      // Create chart
      this.createAltitudeChart(expandedRow, date)
    }
  }

  createAltitudeChart(expandedRow, date) {
    const chartContainer = expandedRow.querySelector('[data-almanac-calendar-target="altitudeChart"]')
    if (!chartContainer) return

    const positionsJson = chartContainer.dataset.positions
    const dateLabel = chartContainer.dataset.date
    const body = chartContainer.dataset.body || 'moon'
    
    if (!positionsJson) return

    try {
      const positions = JSON.parse(positionsJson)
      
      // Data is already sampled server-side
      const sampledData = positions.map(pos => ({
        minute: pos.m,
        altitude: pos.alt
      }))

      // Set up dimensions
      const margin = { top: 40, right: 30, bottom: 60, left: 60 }
      const containerWidth = chartContainer.offsetWidth
      const width = containerWidth - margin.left - margin.right
      const height = 250 - margin.top - margin.bottom
      const totalWidth = containerWidth
      const totalHeight = height + margin.top + margin.bottom

      // Clear any existing canvas
      chartContainer.innerHTML = ''

      // Create canvas
      const canvas = document.createElement('canvas')
      canvas.width = totalWidth
      canvas.height = totalHeight
      canvas.style.width = '100%'
      canvas.style.height = 'auto'
      chartContainer.appendChild(canvas)

      const ctx = canvas.getContext('2d')
      
      // Scales
      const x = d3.scaleLinear()
        .domain([0, 1440])
        .range([0, width])

      const y = d3.scaleLinear()
        .domain([-90, 90])
        .range([height, 0])

      // Translate context to account for margins
      ctx.save()
      ctx.translate(margin.left, margin.top)

      // Helper function to draw smooth curve through points
      const drawSmoothCurve = (points, closeToBottom = false) => {
        if (points.length === 0) return

        ctx.beginPath()
        
        if (closeToBottom) {
          ctx.moveTo(x(points[0].minute), height)
          ctx.lineTo(x(points[0].minute), y(points[0].altitude))
        } else {
          ctx.moveTo(x(points[0].minute), y(points[0].altitude))
        }

        // Use quadratic curves for smooth interpolation
        for (let i = 0; i < points.length - 1; i++) {
          const current = points[i]
          const next = points[i + 1]
          
          const xCurrent = x(current.minute)
          const yCurrent = y(current.altitude)
          const xNext = x(next.minute)
          const yNext = y(next.altitude)
          
          // Control point is midway between current and next
          const cpX = (xCurrent + xNext) / 2
          const cpY = (yCurrent + yNext) / 2
          
          ctx.quadraticCurveTo(xCurrent, yCurrent, cpX, cpY)
        }
        
        // Draw to last point
        const last = points[points.length - 1]
        ctx.lineTo(x(last.minute), y(last.altitude))
        
        if (closeToBottom) {
          ctx.lineTo(x(last.minute), height)
          ctx.closePath()
        }
      }

      // Draw area fill
      ctx.fillStyle = 'rgba(59, 130, 246, 0.1)'
      drawSmoothCurve(sampledData, true)
      ctx.fill()

      // Draw line
      ctx.strokeStyle = 'rgb(59, 130, 246)'
      ctx.lineWidth = 2
      drawSmoothCurve(sampledData, false)
      ctx.stroke()

      // Draw horizon line at 0°
      ctx.strokeStyle = 'rgba(255, 0, 0, 0.5)'
      ctx.lineWidth = 1
      ctx.setLineDash([4, 4])
      ctx.beginPath()
      ctx.moveTo(0, y(0))
      ctx.lineTo(width, y(0))
      ctx.stroke()
      ctx.setLineDash([])

      // Draw axes
      ctx.strokeStyle = '#000'
      ctx.lineWidth = 1
      ctx.fillStyle = '#000'
      ctx.font = '10px sans-serif'
      ctx.textAlign = 'center'

      // X axis
      ctx.beginPath()
      ctx.moveTo(0, height)
      ctx.lineTo(width, height)
      ctx.stroke()

      // X axis ticks and labels (every 3 hours)
      for (let minute = 0; minute <= 1440; minute += 180) {
        const xPos = x(minute)
        ctx.beginPath()
        ctx.moveTo(xPos, height)
        ctx.lineTo(xPos, height + 6)
        ctx.stroke()
        
        const hour = Math.floor(minute / 60)
        const label = `${hour.toString().padStart(2, '0')}:00`
        ctx.save()
        ctx.translate(xPos, height + 10)
        ctx.rotate(-Math.PI / 4)
        ctx.textAlign = 'end'
        ctx.fillText(label, 0, 0)
        ctx.restore()
      }

      // Y axis
      ctx.beginPath()
      ctx.moveTo(0, 0)
      ctx.lineTo(0, height)
      ctx.stroke()

      // Y axis ticks and labels
      ctx.textAlign = 'right'
      ctx.textBaseline = 'middle'
      for (let deg = -90; deg <= 90; deg += 30) {
        const yPos = y(deg)
        ctx.beginPath()
        ctx.moveTo(-6, yPos)
        ctx.lineTo(0, yPos)
        ctx.stroke()
        ctx.fillText(deg.toString() + '°', -10, yPos)
      }

      ctx.restore()

      // Draw title
      ctx.fillStyle = '#000'
      ctx.font = 'bold 14px sans-serif'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'top'
      const bodyName = body.charAt(0).toUpperCase() + body.slice(1)
      ctx.fillText(`${bodyName} Altitude - ${dateLabel}`, totalWidth / 2, 10)

      // Y axis label
      ctx.save()
      ctx.translate(15, totalHeight / 2)
      ctx.rotate(-Math.PI / 2)
      ctx.font = '12px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('Altitude (degrees)', 0, 0)
      ctx.restore()

      // X axis label
      ctx.font = '12px sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('Time', totalWidth / 2, totalHeight - 10)

    } catch (error) {
      console.error('Error creating altitude chart:', error)
    }
  }
}
