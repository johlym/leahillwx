import { Controller } from "@hotwired/stimulus"
import {
  applyMenuOpenState,
  firstMenuLink,
  shouldCloseOnKeydown,
  shouldCloseOnOutsideClick,
} from "./helpers/mobile_menu"

export default class extends Controller {
  static targets = ["menu", "button", "openIcon", "closeIcon", "label"]

  connect() {
    this.isOpen = false
    this.boundKeydown = this.keydown.bind(this)
    this.boundOutsideClick = this.outsideClick.bind(this)
    this.boundCloseFromTurbo = this.closeFromTurbo.bind(this)

    document.addEventListener("keydown", this.boundKeydown)
    document.addEventListener("click", this.boundOutsideClick)
    document.addEventListener("turbo:before-cache", this.boundCloseFromTurbo)
    document.addEventListener("turbo:load", this.boundCloseFromTurbo)

    this.close({ restoreFocus: false })
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
    document.removeEventListener("click", this.boundOutsideClick)
    document.removeEventListener("turbo:before-cache", this.boundCloseFromTurbo)
    document.removeEventListener("turbo:load", this.boundCloseFromTurbo)
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.isOpen = true
    this.applyState()
    firstMenuLink(this.menuTarget)?.focus()
  }

  close({ restoreFocus = true } = {}) {
    const wasOpen = this.isOpen
    this.isOpen = false
    this.applyState()
    if (restoreFocus && wasOpen && this.hasButtonTarget) {
      this.buttonTarget.focus()
    }
  }

  closeFromTurbo() {
    this.close({ restoreFocus: false })
  }

  keydown(event) {
    if (!shouldCloseOnKeydown(event, this.isOpen)) return
    event.preventDefault()
    this.close()
  }

  outsideClick(event) {
    if (!this.isOpen) return
    if (!shouldCloseOnOutsideClick(event, this.element)) return
    this.close({ restoreFocus: false })
  }

  applyState() {
    applyMenuOpenState({
      menu: this.menuTarget,
      button: this.buttonTarget,
      openIcon: this.hasOpenIconTarget ? this.openIconTarget : null,
      closeIcon: this.hasCloseIconTarget ? this.closeIconTarget : null,
      label: this.hasLabelTarget ? this.labelTarget : null,
      isOpen: this.isOpen,
    })
  }
}
