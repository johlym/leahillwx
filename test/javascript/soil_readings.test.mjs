import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { renderSoilReadings, soilChannelValueHtml } from "../../app/javascript/controllers/helpers/soil_readings.js"

describe("auxiliary sensor pair display", () => {
  it("shows temperature when the humidity side of a pair stops reporting", () => {
    const html = renderSoilReadings([
      { channel: 1, name: "Front Yard", temperature_f: 54 },
      { channel: 2, name: "TH Ch 1", temperature_f: 82, battery_low: false },
    ])

    assert.match(html, /Front Yard/)
    assert.match(html, /54<\/span><span class="soil-channel-unit">°F<\/span>/)
    assert.match(html, /TH Ch 1/)
    assert.match(html, /82<\/span><span class="soil-channel-unit">°F<\/span>/)
    assert.doesNotMatch(html, /N\/A/)
  })

  it("shows humidity when the temperature side of a pair stops reporting", () => {
    const html = soilChannelValueHtml({ humidity: 40, battery_low: true })

    assert.match(html, /40<\/span><span class="soil-channel-unit">%<\/span>/)
    assert.doesNotMatch(html, /°F/)
    assert.doesNotMatch(html, /N\/A/)
  })

  it("keeps humidity and temperature together when both are reporting", () => {
    const html = soilChannelValueHtml({ humidity: 40, temperature_f: 82 })

    assert.equal(
      html,
      `<span class="soil-channel-number">40</span><span class="soil-channel-unit">%</span><span class="soil-channel-temp"> / 82°F</span>`
    )
  })

  it("prefers soil moisture over wireless humidity for the percent", () => {
    const html = soilChannelValueHtml({ moisture: 62, humidity: 45, temperature_f: 68 })

    assert.match(html, />62</)
    assert.doesNotMatch(html, />45</)
    assert.match(html, /\/ 68°F/)
  })

  it("shows N/A only when neither side is reporting", () => {
    assert.equal(soilChannelValueHtml({ name: "TH Ch 1" }), `<span class="soil-channel-na">N/A</span>`)
    assert.match(renderSoilReadings([]), /No sensors reporting/)
    assert.match(renderSoilReadings(null), /No sensors reporting/)
  })

  it("escapes sensor names", () => {
    const html = renderSoilReadings([{ channel: 1, name: `A & B <script>"'`, moisture: 10 }])

    assert.match(html, /A &amp; B &lt;script&gt;&quot;&#39;/)
    assert.doesNotMatch(html, /<script>/)
  })
})
