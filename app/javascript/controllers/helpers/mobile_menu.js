export const OPEN_LABEL = "Open main menu"
export const CLOSE_LABEL = "Close main menu"

export function applyMenuOpenState({ menu, button, openIcon, closeIcon, label, isOpen }) {
  menu.classList.toggle("hidden", !isOpen)
  button.setAttribute("aria-expanded", isOpen ? "true" : "false")
  if (openIcon) openIcon.hidden = isOpen
  if (closeIcon) closeIcon.hidden = !isOpen
  if (label) label.textContent = isOpen ? CLOSE_LABEL : OPEN_LABEL
}

export function shouldCloseOnKeydown(event, isOpen) {
  return Boolean(isOpen && event?.key === "Escape")
}

export function shouldCloseOnOutsideClick(event, root) {
  if (!root || !event?.target) return false
  return !root.contains(event.target)
}

export function firstMenuLink(menu) {
  return menu?.querySelector?.("a, button") ?? null
}
