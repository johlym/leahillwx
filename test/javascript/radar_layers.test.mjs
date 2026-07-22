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
  buildLibreWxrRadarFrames,
  buildLibreWxrSatelliteFrames,
  resolvePreservedFrameIndex,
  boundsForRadius,
  ridgeProductForTilt,
  tileUrlsForViewport,
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
})

describe("buildLibreWxrRadarFrames", () => {
  it("builds past and nowcast tile URL templates with snow colors", () => {
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
      `https://api.librewxr.net/v2/radar/1784601600/256/{z}/{x}/{y}/${LIBREWXR_COLOR_SCHEME}/${LIBREWXR_OPTIONS_SNOW}.png`,
    )
    assert.equal(frames[1].isNowcast, true)
    assert.match(frames[0].label, /^Past · /)
    assert.match(frames[1].label, /^Future · /)
    assert.match(frames[1].urlTemplate, /1784602200/)
    assert.doesNotMatch(frames[0].urlTemplate, /arrows=/)
  })

  it("omits nowcast when disabled", () => {
    const frames = buildLibreWxrRadarFrames(
      {
        host: "https://api.librewxr.net",
        radar: {
          past: [{ time: 1784601600, path: "/v2/radar/1784601600" }],
          nowcast: [{ time: 1784602200, path: "/v2/radar/1784602200" }],
        },
      },
      { includeNowcast: false, options: "1_0" },
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
      { tileHost: "https://radar.example.com/" },
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

  it("falls back to the temporally closest frame", () => {
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

  it("keeps nowcast playback from snapping back into past radar", () => {
    const frames = [
      { id: "past-1", time: new Date("2026-07-22T12:00:00Z"), isNowcast: false },
      { id: "past-2", time: new Date("2026-07-22T12:10:00Z"), isNowcast: false },
      { id: "nc-1", time: new Date("2026-07-22T12:20:00Z"), isNowcast: true },
      { id: "nc-2", time: new Date("2026-07-22T12:30:00Z"), isNowcast: true },
    ]
    assert.equal(
      resolvePreservedFrameIndex(frames, {
        id: "nc-old",
        time: new Date("2026-07-22T12:28:00Z"),
        isNowcast: true,
      }),
      3,
    )
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

describe("tileUrlsForViewport", () => {
  it("expands the template for tiles covering the pixel bounds", () => {
    const urls = tileUrlsForViewport(
      "https://example.com/{z}/{x}/{y}/6/1_1.png",
      {
        zoom: 7,
        pixelMinX: 256,
        pixelMinY: 512,
        pixelMaxX: 300,
        pixelMaxY: 600,
        tileSize: 256,
        pad: 0,
      },
    )

    assert.deepEqual(urls, [
      "https://example.com/7/1/2/6/1_1.png",
    ])
  })

  it("pads the tile range and strips retina placeholders", () => {
    const urls = tileUrlsForViewport(
      "https://example.com/{z}/{x}/{y}{r}.png",
      {
        zoom: 5,
        pixelMinX: 0,
        pixelMinY: 0,
        pixelMaxX: 10,
        pixelMaxY: 10,
        tileSize: 256,
        pad: 1,
      },
    )

    assert.equal(urls.length, 9)
    assert.ok(urls.includes("https://example.com/5/0/0.png"))
    assert.ok(urls.includes("https://example.com/5/-1/-1.png"))
    assert.ok(urls.every((url) => !url.includes("{r}")))
  })
})
