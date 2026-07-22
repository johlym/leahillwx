import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  LEVEL3_PLOT_SIZE,
  LEVEL3_PLOT_SIZE_MOBILE,
  boundsForRadar,
  dbzColor,
  loadFramesWithConcurrency,
  parseLevel3KeyTime,
  preferredLevel3MaxFrames,
  preferredLevel3PlotSize,
  requireLoadedLevel3Frames,
  revokeLevel3FrameUrls,
  shouldLimitRadarMemory,
} from "../../app/javascript/controllers/helpers/level3_utils.js"

describe("LEVEL3_PLOT_SIZE", () => {
  it("uses full native 1800px resolution", () => {
    assert.equal(LEVEL3_PLOT_SIZE, 1800)
  })
})

describe("shouldLimitRadarMemory / preferred Level III sizing", () => {
  it("limits memory for coarse pointers and low deviceMemory", () => {
    assert.equal(
      shouldLimitRadarMemory({
        matchMedia: () => ({ matches: false }),
        navigator: { deviceMemory: 8 },
      }),
      false,
    )
    assert.equal(
      shouldLimitRadarMemory({
        matchMedia: (query) => ({ matches: query.includes("pointer: coarse") }),
        navigator: {},
      }),
      true,
    )
    assert.equal(
      shouldLimitRadarMemory({
        matchMedia: () => ({ matches: false }),
        navigator: { deviceMemory: 4 },
      }),
      true,
    )
  })

  it("picks smaller plot size and fewer frames when limited", () => {
    const limited = {
      matchMedia: () => ({ matches: true }),
      navigator: {},
    }
    assert.equal(preferredLevel3PlotSize(limited), LEVEL3_PLOT_SIZE_MOBILE)
    assert.equal(preferredLevel3MaxFrames(limited), 12)
    assert.equal(
      preferredLevel3PlotSize({
        matchMedia: () => ({ matches: false }),
        navigator: { deviceMemory: 8 },
      }),
      LEVEL3_PLOT_SIZE,
    )
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
  it("skips weak returns and follows the rain ladder", () => {
    assert.equal(dbzColor(4), null)
    assert.equal(dbzColor(10), "rgba(144, 238, 144, 0.85)") // light green
    assert.equal(dbzColor(30), "rgba(0, 100, 0, 0.85)") // dark green
    assert.equal(dbzColor(42), "rgba(255, 140, 0, 0.85)") // orange
    assert.equal(dbzColor(52), "rgba(140, 0, 0, 0.9)") // dark red
    assert.equal(dbzColor(60), "rgba(160, 0, 200, 0.9)") // purple
    assert.equal(dbzColor(70), "rgba(255, 255, 255, 0.95)") // white
  })
})

describe("requireLoadedLevel3Frames", () => {
  it("returns frames when at least one load succeeded", () => {
    const frames = [{ id: "a" }]
    assert.equal(
      requireLoadedLevel3Frames(3, frames, { sector: "ATX", product: "NAB" }),
      frames,
    )
  })

  it("throws when keys were listed but every load failed", () => {
    assert.throws(
      () => requireLoadedLevel3Frames(4, [], { sector: "ATX", product: "NAB" }),
      /listed 4 key\(s\) for ATX\/NAB but all frame loads failed/,
    )
  })
})

describe("loadFramesWithConcurrency", () => {
  it("keeps successful frames when some loads reject", async () => {
    const frames = await loadFramesWithConcurrency(
      ["a", "bad", "c", "d"],
      async (key) => {
        if (key === "bad") throw new Error("fetch failed")
        return { id: key, url: `blob:${key}` }
      },
      { concurrency: 3 },
    )

    assert.deepEqual(
      frames.map((f) => f.id),
      ["a", "c", "d"],
    )
  })

  it("revokes blob URLs already loaded when a later batch aborts", async () => {
    const revoked = []
    const originalRevoke = URL.revokeObjectURL
    URL.revokeObjectURL = (url) => {
      revoked.push(url)
    }

    try {
      await assert.rejects(
        () =>
          loadFramesWithConcurrency(
            ["a", "b", "c", "d"],
            (key) => {
              if (key === "d") throw new Error("unexpected abort")
              return Promise.resolve({ id: key, url: `blob:${key}` })
            },
            { concurrency: 3 },
          ),
        /unexpected abort/,
      )

      assert.deepEqual(revoked.sort(), ["blob:a", "blob:b", "blob:c"])
    } finally {
      URL.revokeObjectURL = originalRevoke
    }
  })
})

describe("revokeLevel3FrameUrls", () => {
  it("revokes blob URLs and ignores non-blob frames", () => {
    const revoked = []
    const originalRevoke = URL.revokeObjectURL
    URL.revokeObjectURL = (url) => {
      revoked.push(url)
    }

    try {
      revokeLevel3FrameUrls([
        { url: "blob:one" },
        { url: "https://example.com/x.png" },
        { url: "blob:two" },
        {},
      ])
      assert.deepEqual(revoked, ["blob:one", "blob:two"])
    } finally {
      URL.revokeObjectURL = originalRevoke
    }
  })
})
