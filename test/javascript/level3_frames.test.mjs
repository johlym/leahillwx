import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  LEVEL3_PLOT_SIZE,
  boundsForRadar,
  dbzColor,
  parseLevel3KeyTime,
} from "../../app/javascript/controllers/helpers/level3_utils.js"

describe("LEVEL3_PLOT_SIZE", () => {
  it("uses full native 1800px resolution", () => {
    assert.equal(LEVEL3_PLOT_SIZE, 1800)
  })
})

describe("parseLevel3KeyTime", () => {
  it("parses Unidata Level III object keys", () => {
    const time = parseLevel3KeyTime("ATX_NAB_2026_07_21_23_08_51")
    assert.equal(time.toISOString(), "2026-07-21T23:08:51.000Z")
  })
})

describe("boundsForRadar", () => {
  it("returns a box centered on the radar site", () => {
    const [[south, west], [north, east]] = boundsForRadar(48.195, -122.496, 460)
    assert.ok(south < 48.195 && north > 48.195)
    assert.ok(west < -122.496 && east > -122.496)
    assert.ok(north - south > 7)
  })
})

describe("dbzColor", () => {
  it("skips weak returns and colors stronger echoes", () => {
    assert.equal(dbzColor(4), null)
    assert.match(dbzColor(25), /^rgba\(/)
    assert.match(dbzColor(55), /^rgba\(/)
  })
})
