// Shared palette helpers so any Stimulus controller can read the
// current time-of-day tokens and re-theme when the palette changes.

export function readPaletteColors() {
  const styles = getComputedStyle(document.documentElement)
  const read = (name, fallback) => {
    const raw = styles.getPropertyValue(name).trim()
    return raw || fallback
  }
  const chartColors = [
    read("--chart-1", "#7aa2ff"),
    read("--chart-2", "#ffb98a"),
    read("--chart-3", "#8ee0b3"),
    read("--chart-4", "#f6d576"),
    read("--chart-5", "#e298d0"),
    read("--chart-6", "#8fd3f1"),
  ]
  return {
    bg: read("--bg", "#141625"),
    surface: read("--surface", "#1c1f30"),
    surface2: read("--surface-2", "#242639"),
    border: read("--border", "#3a3d55"),
    text: read("--text", "#eaeaf6"),
    textStrong: read("--text-strong", "#ffffff"),
    muted: read("--muted", "#a0a4c0"),
    subtle: read("--subtle", "#8d92ae"),
    accent: read("--accent", "#8fa6ff"),
    accentStrong: read("--accent-strong", "#a9b8ff"),
    success: read("--success", "#7ad2a1"),
    warning: read("--warning", "#e5c07b"),
    danger: read("--danger", "#e07177"),
    chartColors,
  }
}

export function withAlpha(color, alpha) {
  if (!color) return `rgba(0,0,0,${alpha})`
  return `color-mix(in oklab, ${color} ${Math.round(alpha * 100)}%, transparent)`
}

// Attaches a MutationObserver that fires `callback` whenever
// `data-palette` on <html> changes. Returns the observer so callers
// can `.disconnect()` in Stimulus `disconnect()`.
export function observePaletteChanges(callback) {
  const observer = new MutationObserver((mutations) => {
    if (mutations.some((m) => m.attributeName === "data-palette")) {
      callback()
    }
  })
  observer.observe(document.documentElement, { attributes: true })
  return observer
}
