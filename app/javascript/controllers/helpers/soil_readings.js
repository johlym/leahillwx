// Auxiliary rows pair a humidity/moisture sensor with a temperature sensor.
// Either side can stop reporting on its own. Show the side that is still live,
// and use N/A only when the row has neither reading.

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;")
}

function asInt(value) {
  return Math.round(parseFloat(value)).toString()
}

function percentFor(reading) {
  return reading.moisture != null ? reading.moisture : reading.humidity
}

export function soilChannelValueHtml(reading) {
  const percent = percentFor(reading)
  const temperature = reading.temperature_f
  const hasPercent = percent != null
  const hasTemperature = temperature != null

  if (!hasPercent && !hasTemperature) {
    return `<span class="soil-channel-na">N/A</span>`
  }

  let html = ""
  if (hasPercent) {
    html += `<span class="soil-channel-number">${asInt(percent)}</span><span class="soil-channel-unit">%</span>`
  }
  if (hasPercent && hasTemperature) {
    html += `<span class="soil-channel-temp"> / ${asInt(temperature)}°F</span>`
  } else if (hasTemperature) {
    html += `<span class="soil-channel-number">${asInt(temperature)}</span><span class="soil-channel-unit">°F</span>`
  }
  return html
}

export function renderSoilReadings(readings) {
  if (!Array.isArray(readings) || readings.length === 0) {
    return `<p class="live-tile-meta">No sensors reporting</p>`
  }

  return readings.map((reading) => {
    const name = escapeHtml(reading.name || `Ch ${reading.channel}`)
    return `<div class="soil-channel">
        <span class="soil-channel-name">${name}</span>
        <span class="soil-channel-value">${soilChannelValueHtml(reading)}</span>
      </div>`
  }).join("")
}
