import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  MOSAIC_OFFSETS,
  RIDGE_PRODUCT,
  buildMosaicFrames,
  buildRidgeFrames,
  buildRainviewerFrames,
  boundsForRadius,
  toIemTimestamp,
  ridgeListUrl,
} from "../../app/javascript/controllers/helpers/radar_layers.js"

describe("buildMosaicFrames", () => {
  it("builds oldest-to-newest frames including current", () => {
    const now = new Date("2026-07-21T12:00:00Z")
    const frames = buildMosaicFrames(now)

    assert.equal(frames.length, MOSAIC_OFFSETS.length)
    assert.equal(frames[0].layer, "nexrad-n0q-m55m")
    assert.equal(frames.at(-1).layer, "nexrad-n0q")
    assert.equal(frames.at(-1).kind, "iem")
  })
})

describe("buildRidgeFrames", () => {
  it("uses N0B product and IEM timestamped layer names", () => {
    const frames = buildRidgeFrames("ATX", [
      { ts: "2026-07-21T04:30Z" },
      { ts: "2026-07-21T04:35Z" },
    ])

    assert.equal(RIDGE_PRODUCT, "N0B")
    assert.equal(frames.length, 2)
    assert.equal(frames[0].layer, "ridge::ATX-N0B-202607210430")
    assert.equal(frames[1].layer, "ridge::ATX-N0B-202607210435")
  })
})

describe("buildRainviewerFrames", () => {
  it("builds tile URL templates from weather-maps.json", () => {
    const frames = buildRainviewerFrames({
      host: "https://tilecache.rainviewer.com",
      radar: {
        past: [{ time: 1784601600, path: "/v2/radar/abc123" }],
      },
    })

    assert.equal(frames.length, 1)
    assert.equal(
      frames[0].urlTemplate,
      "https://tilecache.rainviewer.com/v2/radar/abc123/256/{z}/{x}/{y}/2/1_1.png",
    )
    assert.equal(frames[0].kind, "rainviewer")
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

describe("toIemTimestamp / ridgeListUrl", () => {
  it("formats UTC minute stamps for IEM APIs", () => {
    const date = new Date("2026-07-21T04:40:12Z")
    assert.equal(toIemTimestamp(date), "202607210440")
    assert.match(
      ridgeListUrl("RTX", date, date),
      /operation=list&radar=RTX&product=N0B&start=2026-07-21T04%3A40Z&end=2026-07-21T04%3A40Z/,
    )
  })
})
