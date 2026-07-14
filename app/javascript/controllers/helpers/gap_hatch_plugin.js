// Hatches the area under line segments that bridge missing data points.
// Pair with dataset.segment.borderDash (see chart_controller) so gap
// bridges read as dashed line + hashed fill.
export const gapHatchPlugin = {
  id: "gapHatch",

  afterDatasetsDraw(chart, _args, pluginOptions) {
    if (!pluginOptions?.enabled) return

    const { ctx, chartArea, scales } = chart
    const yScale = scales.y
    if (!yScale || !chartArea) return

    const yBase = yScale.getPixelForValue(yScale.min)

    chart.data.datasets.forEach((dataset, datasetIndex) => {
      const meta = chart.getDatasetMeta(datasetIndex)
      if (dataset.hidden || dataset.showLine === false || dataset.borderDash?.length || meta.type !== "line" || !meta.data?.length) return

      const values = dataset.data || []
      const points = meta.data
      let lastPresent = null

      for (let i = 0; i < values.length; i += 1) {
        if (!isPresent(values[i])) continue

        if (lastPresent !== null && i - lastPresent > 1) {
          const p0 = points[lastPresent]
          const p1 = points[i]
          if (p0 && p1 && Number.isFinite(p0.x) && Number.isFinite(p1.x)) {
            hatchUnderSegment(ctx, chartArea, p0, p1, yBase, dataset.borderColor)
          }
        }
        lastPresent = i
      }
    })
  },
}

function isPresent(value) {
  return value !== null && value !== undefined && !(typeof value === "number" && Number.isNaN(value))
}

function hatchUnderSegment(ctx, chartArea, p0, p1, yBase, color) {
  const x0 = p0.x
  const y0 = p0.y
  const x1 = p1.x
  const y1 = p1.y

  ctx.save()
  ctx.beginPath()
  ctx.moveTo(x0, y0)
  ctx.lineTo(x1, y1)
  ctx.lineTo(x1, yBase)
  ctx.lineTo(x0, yBase)
  ctx.closePath()
  ctx.clip()

  const stroke = typeof color === "string" ? color : "rgba(128, 128, 128, 0.5)"
  ctx.strokeStyle = stroke
  ctx.globalAlpha = 0.3
  ctx.lineWidth = 1

  const spacing = 4
  const left = Math.min(x0, x1)
  const right = Math.max(x0, x1)
  const top = chartArea.top
  const bottom = Math.max(yBase, chartArea.bottom)
  const span = bottom - top

  for (let x = left - span; x < right + span; x += spacing) {
    ctx.beginPath()
    ctx.moveTo(x, bottom)
    ctx.lineTo(x + span, top)
    ctx.stroke()
  }

  ctx.restore()
}
