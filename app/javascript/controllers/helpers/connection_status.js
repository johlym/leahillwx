export const STATUS_LIVE = "live"
export const STATUS_STALE = "stale"
export const STATUS_OFFLINE = "offline"

export function isCableStreamOpen(streamSource) {
  try {
    return Boolean(streamSource?.subscription?.consumer?.connection?.isOpen?.())
  } catch {
    return false
  }
}

export function resolveConnectionStatus({ streamOpen, hasLastUpdated }) {
  if (streamOpen) return STATUS_LIVE
  if (hasLastUpdated) return STATUS_STALE
  return STATUS_OFFLINE
}

export function applyConnectionBadge(badge, label, status) {
  if (!badge) return

  badge.hidden = false
  badge.classList.remove("hidden")
  badge.dataset.status = status
  badge.classList.toggle("site-header-live-row-live", status === STATUS_LIVE)
  badge.classList.toggle("site-header-live-row-stale", status === STATUS_STALE)
  badge.classList.toggle("site-header-live-row-offline", status === STATUS_OFFLINE)
  if (label) label.textContent = status.toUpperCase()
}
