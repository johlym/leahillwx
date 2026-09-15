import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  STATUS_LIVE,
  STATUS_OFFLINE,
  STATUS_STALE,
  applyConnectionBadge,
  isCableStreamOpen,
  resolveConnectionStatus,
} from "../../app/javascript/controllers/helpers/connection_status.js"

function createClassList(initial = []) {
  const classes = new Set(initial)
  return {
    add: (name) => classes.add(name),
    remove: (name) => classes.delete(name),
    toggle(name, force) {
      if (force === true) classes.add(name)
      else if (force === false) classes.delete(name)
      else if (classes.has(name)) classes.delete(name)
      else classes.add(name)
      return classes.has(name)
    },
    contains: (name) => classes.has(name),
  }
}

describe("isCableStreamOpen", () => {
  it("is true only when the Turbo Cable subscription is open", () => {
    const openSource = {
      subscription: { consumer: { connection: { isOpen: () => true } } },
    }
    const closedSource = {
      subscription: { consumer: { connection: { isOpen: () => false } } },
    }

    assert.equal(isCableStreamOpen(openSource), true)
    assert.equal(isCableStreamOpen(closedSource), false)
    assert.equal(isCableStreamOpen(null), false)
    assert.equal(isCableStreamOpen({}), false)
  })
})

describe("resolveConnectionStatus", () => {
  it("prefers LIVE when the Cable stream is open", () => {
    assert.equal(
      resolveConnectionStatus({ streamOpen: true, hasLastUpdated: false }),
      STATUS_LIVE,
    )
  })

  it("is STALE when the stream is down but a last reading exists", () => {
    assert.equal(
      resolveConnectionStatus({ streamOpen: false, hasLastUpdated: true }),
      STATUS_STALE,
    )
  })

  it("is OFFLINE when there is no stream and no last reading", () => {
    assert.equal(
      resolveConnectionStatus({ streamOpen: false, hasLastUpdated: false }),
      STATUS_OFFLINE,
    )
  })
})

describe("applyConnectionBadge", () => {
  it("shows LIVE / STALE / OFFLINE labels from a mock stream source", () => {
    const badge = {
      hidden: true,
      classList: createClassList(["hidden"]),
      dataset: {},
    }
    const label = { textContent: "" }

    applyConnectionBadge(badge, label, resolveConnectionStatus({
      streamOpen: isCableStreamOpen({
        subscription: { consumer: { connection: { isOpen: () => true } } },
      }),
      hasLastUpdated: true,
    }))
    assert.equal(label.textContent, "LIVE")
    assert.equal(badge.dataset.status, STATUS_LIVE)
    assert.equal(badge.classList.contains("hidden"), false)
    assert.equal(badge.classList.contains("site-header-live-row-live"), true)

    applyConnectionBadge(badge, label, resolveConnectionStatus({
      streamOpen: isCableStreamOpen({
        subscription: { consumer: { connection: { isOpen: () => false } } },
      }),
      hasLastUpdated: true,
    }))
    assert.equal(label.textContent, "STALE")
    assert.equal(badge.classList.contains("site-header-live-row-stale"), true)

    applyConnectionBadge(badge, label, resolveConnectionStatus({
      streamOpen: isCableStreamOpen(null),
      hasLastUpdated: false,
    }))
    assert.equal(label.textContent, "OFFLINE")
    assert.equal(badge.classList.contains("site-header-live-row-offline"), true)
  })
})
