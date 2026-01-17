import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    data: Array,
    title: String
  }

  connect() {
    if (this.hasDataValue && this.dataValue.length > 0) {
      this.renderGraph()
    }
  }

  renderGraph() {
    const data = this.dataValue
    const margin = { top: 40, right: 150, bottom: 60, left: 60 }
    const containerWidth = this.element.offsetWidth
    const width = containerWidth - margin.left - margin.right
    const height = 500 - margin.top - margin.bottom

    d3.select(this.element).select("svg").remove()

    const svg = d3.select(this.element)
      .append("svg")
      .attr("width", "100%")
      .attr("height", height + margin.top + margin.bottom)
      .attr("viewBox", `0 0 ${containerWidth} ${height + margin.top + margin.bottom}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleBand()
      .domain(data.map(d => d.date))
      .range([0, width])
      .padding(0.1)

    const allTemps = data.flatMap(d => [d.high, d.low, d.mean].filter(v => v !== null))
    const yMin = Math.floor(Math.min(...allTemps) / 10) * 10
    const yMax = Math.ceil(Math.max(...allTemps) / 10) * 10

    const y = d3.scaleLinear()
      .domain([yMin, yMax])
      .range([height, 0])

    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x))
      .selectAll("text")
      .attr("transform", "rotate(-45)")
      .style("text-anchor", "end")

    svg.append("g")
      .call(d3.axisLeft(y))

    svg.append("text")
      .attr("x", width / 2)
      .attr("y", -10)
      .attr("text-anchor", "middle")
      .style("font-size", "16px")
      .style("font-weight", "bold")
      .text(this.titleValue || "Temperature Data")

    svg.append("text")
      .attr("x", width / 2)
      .attr("y", height + 50)
      .attr("text-anchor", "middle")
      .style("font-size", "12px")
      .text("Day")

    svg.append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -height / 2)
      .attr("y", -40)
      .attr("text-anchor", "middle")
      .style("font-size", "12px")
      .text("Temperature (°F)")

    const lines = [
      { key: "high", color: "#ff7f0e", label: "High" },
      { key: "low", color: "#1f77b4", label: "Low" },
      { key: "mean", color: "#2ca02c", label: "Feels Like (Mean)" }
    ]

    lines.forEach(lineConfig => {
      const lineData = data.filter(d => d[lineConfig.key] !== null)
      
      if (lineData.length > 0) {
        const line = d3.line()
          .x(d => x(d.date) + x.bandwidth() / 2)
          .y(d => y(d[lineConfig.key]))
          .curve(d3.curveMonotoneX)

        svg.append("path")
          .datum(lineData)
          .attr("fill", "none")
          .attr("stroke", lineConfig.color)
          .attr("stroke-width", 2)
          .attr("d", line)

        svg.selectAll(`.dot-${lineConfig.key}`)
          .data(lineData)
          .enter()
          .append("circle")
          .attr("class", `dot-${lineConfig.key}`)
          .attr("cx", d => x(d.date) + x.bandwidth() / 2)
          .attr("cy", d => y(d[lineConfig.key]))
          .attr("r", 4)
          .attr("fill", lineConfig.color)
          .append("title")
          .text(d => `${lineConfig.label}: ${d[lineConfig.key]}°F`)
      }
    })

    const legend = svg.append("g")
      .attr("transform", `translate(${width + 10}, 20)`)

    lines.forEach((lineConfig, i) => {
      const legendRow = legend.append("g")
        .attr("transform", `translate(0, ${i * 25})`)

      legendRow.append("rect")
        .attr("width", 20)
        .attr("height", 3)
        .attr("fill", lineConfig.color)

      legendRow.append("text")
        .attr("x", 25)
        .attr("y", 3)
        .style("font-size", "12px")
        .style("alignment-baseline", "middle")
        .text(lineConfig.label)
    })
  }
}
