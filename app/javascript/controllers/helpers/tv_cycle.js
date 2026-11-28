export const DEFAULT_INTERVAL_MS = 10000
export const FADE_MS = 500

export function wrapIndex(index, count) {
  if (!count) return 0
  return ((index % count) + count) % count
}

// Whole seconds left in the frame. The ring reaches zero as the slide
// changes, so the number never displays 0.
export function countdownSeconds(remainingMs) {
  const seconds = Math.ceil(Math.max(0, remainingMs) / 1000)
  return Math.max(1, seconds)
}

// 0 is a full ring, 100 is empty. pathLength on the circle is 100.
export function ringDashOffset(remainingMs, intervalMs) {
  if (!Number.isFinite(intervalMs) || intervalMs <= 0) return 100
  const fraction = Math.min(1, Math.max(0, remainingMs / intervalMs))
  return (1 - fraction) * 100
}

export function slideAnnouncement(label, index, count) {
  return `${label}, ${index + 1} of ${count}`
}
