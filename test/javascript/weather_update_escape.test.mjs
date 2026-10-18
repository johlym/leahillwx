import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const source = readFileSync(join(root, "app/javascript/controllers/weather_update_controller.js"), "utf8")

describe("weather_update_controller soil escaping", () => {
  it("defines escapeHtml and uses it for soil sensor names", () => {
    assert.match(source, /escapeHtml\(value\)/)
    assert.match(source, /this\.escapeHtml\(reading\.name/)
    assert.match(source, /replaceAll\("&", "&amp;"\)/)
  })
})
