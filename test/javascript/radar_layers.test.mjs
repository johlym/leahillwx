import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  RIDGE_PRODUCT,
  RIDGE_TILTS,
  CARTO_DARK_URL,
  LIBREWXR_COLOR_SCHEME,
  LIBREWXR_DEFAULT_HOST,
  LIBREWXR_OPTIONS_SNOW,
  normalizeLibreWxrHost,
  resolveLibreWxrTileHost,
  librewxrMetadataUrl,
  librewxrAlertsUrl,
  buildLibreWxrRadarFrames,
  buildLibreWxrSatelliteFrames,
  resolvePreservedFrameIndex,
  boundsForRadius,
  ridgeProductForTilt,
  alertPathStyle,
  alertPopupHtml,
} from "../../app/javascript/controllers/helpers/radar_layers.js"

describe("ridgeProductForTilt", () => {
  it("maps display tilts to Level III products", () => {
    assert.deepEqual(
      RIDGE_TILTS.map((t) => t.degrees),
      ["0.5", "1.0", "1.5"],
    )
    assert.equal(RIDGE_PRODUCT, "N0B")
    assert.equal(ridgeProductForTilt("0.5"), "N0B")
    assert.equal(ridgeProductForTilt("1.0"), "NAB")
    assert.equal(ridgeProductForTilt("1.5"), "N1B")
    assert.equal(ridgeProductForTilt("9.9"), "N0B")
  })
})

describe("LibreWXR URL helpers", () => {
  it("normalizes host and metadata URLs", () => {
    assert.equal(normalizeLibreWxrHost("https://api.librewxr.net/"), LIBREWXR_DEFAULT_HOST)
    assert.equal(
      normalizeLibreWxrHost("https://api.librewxr.net/public/weather-maps.json"),
      LIBREWXR_DEFAULT_HOST,
    )
    assert.equal(
      librewxrMetadataUrl("https://radar.example.com"),
      "https://radar.example.com/public/weather-maps.json",
    )
  })

  it("builds alerts URLs for point and bbox queries", () => {
    assert.equal(
      librewxrAlertsUrl(LIBREWXR_DEFAULT_HOST, { lat: 47.3, lon: -122.2 }),
      "https://api.librewxr.net/v2/alerts?lat=47.3&lon=-122.2",
    )
    assert.equal(
      librewxrAlertsUrl(LIBREWXR_DEFAULT_HOST, { bbox: "-123,46,-121,48" }),
      "https://api.librewxr.net/v2/alerts?bbox=-123%2C46%2C-121%2C48",
    )
  })
})

describe("buildLibreWxrRadarFrames", () => {
  it("builds past and nowcast tile URL templates with snow and arrows", () => {
    const frames = buildLibreWxrRadarFrames({
      host: "https://api.librewxr.net",
      radar: {
        past: [{ time: 1784601600, path: "/v2/radar/1784601600" }],
        nowcast: [{ time: 1784602200, path: "/v2/radar/1784602200" }],
      },
    })

    assert.equal(frames.length, 2)
    assert.equal(frames[0].kind, "librewxr")
    assert.equal(frames[0].isNowcast, false)
    assert.equal(
      frames[0].urlTemplate,
      `https://api.librewxr.net/v2/radar/1784601600/256/{z}/{x}/{y}/${LIBREWXR_COLOR_SCHEME}/${LIBREWXR_OPTIONS_SNOW}.png?arrows=light`,
    )
    assert.equal(frames[1].isNowcast, true)
    assert.match(frames[1].label, /^Nowcast · /)
    assert.match(frames[1].urlTemplate, /1784602200/)
  })

  it("omits nowcast and arrows when disabled", () => {
    const frames = buildLibreWxrRadarFrames(
      {
        host: "https://api.librewxr.net",
        radar: {
          past: [{ time: 1784601600, path: "/v2/radar/1784601600" }],
          nowcast: [{ time: 1784602200, path: "/v2/radar/1784602200" }],
        },
      },
      { includeNowcast: false, arrows: null, options: "1_0" },
    )

    assert.equal(frames.length, 1)
    assert.equal(
      frames[0].urlTemplate,
      "https://api.librewxr.net/v2/radar/1784601600/256/{z}/{x}/{y}/6/1_0.png",
    )
  })

  it("prefers configured tileHost over metadata host", () => {
    assert.equal(
      resolveLibreWxrTileHost({ host: "https://api.librewxr.net" }, "https://radar.example.com"),
      "https://radar.example.com",
    )

    const frames = buildLibreWxrRadarFrames(
      {
        host: "https://api.librewxr.net",
        radar: { past: [{ time: 1784601600, path: "/v2/radar/1784601600" }] },
      },
      { tileHost: "https://radar.example.com/", arrows: null },
    )

    assert.equal(
      frames[0].urlTemplate,
      "https://radar.example.com/v2/radar/1784601600/256/{z}/{x}/{y}/6/1_1.png",
    )
  })
})

describe("buildLibreWxrSatelliteFrames", () => {
  it("builds GMGSI satellite tile templates", () => {
    const frames = buildLibreWxrSatelliteFrames({
      host: "https://api.librewxr.net",
      satellite: {
        infrared: [{ time: 1784725200, path: "/v2/satellite/1784725200" }],
      },
    })

    assert.equal(frames.length, 1)
    assert.equal(frames[0].kind, "librewxr-satellite")
    assert.equal(
      frames[0].urlTemplate,
      "https://api.librewxr.net/v2/satellite/1784725200/256/{z}/{x}/{y}/0/0_0.png",
    )
  })

  it("uses configured tileHost for satellite tiles", () => {
    const frames = buildLibreWxrSatelliteFrames(
      {
        host: "https://api.librewxr.net",
        satellite: {
          infrared: [{ time: 1784725200, path: "/v2/satellite/1784725200" }],
        },
      },
      { tileHost: "https://radar.example.com" },
    )

    assert.match(frames[0].urlTemplate, /^https:\/\/radar\.example\.com\//)
  })
})

describe("resolvePreservedFrameIndex", () => {
  it("keeps the same frame id when still present", () => {
    const frames = [
      { id: "a", time: new Date("2026-07-22T12:00:00Z") },
      { id: "b", time: new Date("2026-07-22T12:10:00Z") },
    ]
    assert.equal(resolvePreservedFrameIndex(frames, frames[1]), 1)
  })

  it("falls back to the latest frame at or before the prior time", () => {
    const frames = [
      { id: "a", time: new Date("2026-07-22T12:00:00Z") },
      { id: "b", time: new Date("2026-07-22T12:10:00Z") },
      { id: "c", time: new Date("2026-07-22T12:20:00Z") },
    ]
    assert.equal(
      resolvePreservedFrameIndex(frames, {
        id: "gone",
        time: new Date("2026-07-22T12:12:00Z"),
      }),
      1,
    )
  })
})

describe("alert helpers", () => {
  it("styles severities and escapes popup HTML", () => {
    assert.equal(alertPathStyle("Extreme").color, "#f43f5e")
    assert.equal(alertPathStyle("Moderate").color, "#eab308")
    const html = alertPopupHtml({
      title: 'Heat <Advisory>',
      severity: "Moderate",
      description: "Stay cool & hydrated",
      expires: 1784759400,
    })
    assert.match(html, /Heat &lt;Advisory&gt;/)
    assert.match(html, /Stay cool &amp; hydrated/)
    assert.match(html, /Severity: Moderate/)
  })
})

describe("boundsForRadius", () => {
  it("returns a box centered on the station", () => {
    const [[south, west], [north, east]] = boundsForRadius(47.3, -122.2, 200)
    assert.ok(south < 47.3 && north > 47.3)
    assert.ok(west < -122.2 && east > -122.2)
    assert.ok(north - south > 4)
  })
})

describe("basemap host", () => {
  it("uses apex CARTO host without letter subdomains", () => {
    assert.match(CARTO_DARK_URL, /^https:\/\/basemaps\.cartocdn\.com\//)
    assert.doesNotMatch(CARTO_DARK_URL, /\{s\}/)
  })
})
