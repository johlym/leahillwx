import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const source = readFileSync(join(root, "app/javascript/controllers/weather_update_controller.js"), "utf8")

describe("weather_update_controller soil rendering", () => {
  it("renders auxiliary rows through the shared pair formatter", () => {
    assert.match(source, /renderSoilReadings/)
    assert.match(source, /return renderSoilReadings\(readings\)/)
  })
})
