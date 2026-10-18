import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  CLOSE_LABEL,
  OPEN_LABEL,
  applyMenuOpenState,
  firstMenuLink,
  shouldCloseOnKeydown,
  shouldCloseOnOutsideClick,
} from "../../app/javascript/controllers/helpers/mobile_menu.js"

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

function createMenuFixture() {
  const firstLink = { id: "first-link" }
  return {
    menu: {
      classList: createClassList(["hidden"]),
      querySelector: () => firstLink,
    },
    button: {
      attrs: { "aria-expanded": "false" },
      setAttribute(name, value) {
        this.attrs[name] = value
      },
    },
    openIcon: { hidden: false },
    closeIcon: { hidden: true },
    label: { textContent: OPEN_LABEL },
    firstLink,
  }
}

describe("applyMenuOpenState", () => {
  it("opens the menu and updates the toggle label", () => {
    const fixture = createMenuFixture()

    applyMenuOpenState({ ...fixture, isOpen: true })

    assert.equal(fixture.menu.classList.contains("hidden"), false)
    assert.equal(fixture.button.attrs["aria-expanded"], "true")
    assert.equal(fixture.openIcon.hidden, true)
    assert.equal(fixture.closeIcon.hidden, false)
    assert.equal(fixture.label.textContent, CLOSE_LABEL)
  })

  it("closes the menu and restores the open label", () => {
    const fixture = createMenuFixture()
    applyMenuOpenState({ ...fixture, isOpen: true })

    applyMenuOpenState({ ...fixture, isOpen: false })

    assert.equal(fixture.menu.classList.contains("hidden"), true)
    assert.equal(fixture.button.attrs["aria-expanded"], "false")
    assert.equal(fixture.openIcon.hidden, false)
    assert.equal(fixture.closeIcon.hidden, true)
    assert.equal(fixture.label.textContent, OPEN_LABEL)
  })
})

describe("shouldCloseOnKeydown", () => {
  it("closes on Escape only while the menu is open", () => {
    assert.equal(shouldCloseOnKeydown({ key: "Escape" }, true), true)
    assert.equal(shouldCloseOnKeydown({ key: "Escape" }, false), false)
    assert.equal(shouldCloseOnKeydown({ key: "Tab" }, true), false)
  })
})

describe("shouldCloseOnOutsideClick", () => {
  it("closes when the click is outside the header", () => {
    const inside = { id: "inside" }
    const outside = { id: "outside" }
    const root = {
      contains: (node) => node === inside,
    }

    assert.equal(shouldCloseOnOutsideClick({ target: outside }, root), true)
    assert.equal(shouldCloseOnOutsideClick({ target: inside }, root), false)
  })
})

describe("firstMenuLink", () => {
  it("returns the first interactive link in the drawer", () => {
    const fixture = createMenuFixture()
    assert.equal(firstMenuLink(fixture.menu), fixture.firstLink)
  })
})
