import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  DEFAULT_INTERVAL_MS,
  FADE_MS,
  countdownSeconds,
  ringDashOffset,
  slideAnnouncement,
  wrapIndex,
} from "../../app/javascript/controllers/helpers/tv_cycle.js"

describe("tv cycle", () => {
  it("holds each screen for 10 seconds and fades for half a second", () => {
    assert.equal(DEFAULT_INTERVAL_MS, 10000)
    assert.equal(FADE_MS, 500)
  })

  it("wraps the slide index in both directions", () => {
    assert.equal(wrapIndex(0, 4), 0)
    assert.equal(wrapIndex(3, 4), 3)
    assert.equal(wrapIndex(4, 4), 0)
    assert.equal(wrapIndex(-1, 4), 3)
    assert.equal(wrapIndex(0, 0), 0)
  })

  it("counts whole seconds and never shows zero", () => {
    assert.equal(countdownSeconds(10000), 10)
    assert.equal(countdownSeconds(9000), 9)
    assert.equal(countdownSeconds(1000), 1)
    assert.equal(countdownSeconds(1), 1)
    assert.equal(countdownSeconds(0), 1)
  })

  it("drains the ring from full to empty", () => {
    assert.equal(ringDashOffset(10000, 10000), 0)
    assert.equal(ringDashOffset(5000, 10000), 50)
    assert.equal(ringDashOffset(0, 10000), 100)
    assert.equal(ringDashOffset(-20, 10000), 100)
    assert.equal(ringDashOffset(10000, 0), 100)
  })

  it("announces the current screen by name and position", () => {
    assert.equal(slideAnnouncement("Current conditions", 0, 4), "Current conditions, 1 of 4")
  })
})
