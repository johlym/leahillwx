/** Super-res base reflectivity range (~248 nmi). */
export const LEVEL3_RANGE_KM = 460

/** Full native plot resolution (~248 nmi diameter at 0.25 mi/bin). */
export const LEVEL3_PLOT_SIZE = 1800

/** Smaller canvas for coarse pointers / narrow viewports (¼ the pixels of 1800²). */
export const LEVEL3_PLOT_SIZE_MOBILE = 900

/** Default animation length; trimmed further on memory-constrained clients. */
export const LEVEL3_MAX_FRAMES = 18
export const LEVEL3_MAX_FRAMES_MOBILE = 12

/**
 * True when we should prefer lower radar memory/CPU (phones, low-RAM devices).
 * @param {{ matchMedia?: Function, deviceMemory?: number }} [env]
 */
export function shouldLimitRadarMemory(env = globalThis) {
  const deviceMemory = env.navigator?.deviceMemory
  if (typeof deviceMemory === "number" && deviceMemory <= 4) return true

  const matchMedia = env.matchMedia?.bind(env)
  if (typeof matchMedia === "function") {
    try {
      if (matchMedia("(pointer: coarse)").matches) return true
      if (matchMedia("(max-width: 640px)").matches) return true
    } catch {
      // ignore invalid matchMedia in tests / unusual hosts
    }
  }
  return false
}

export function preferredLevel3PlotSize(env = globalThis) {
  return shouldLimitRadarMemory(env) ? LEVEL3_PLOT_SIZE_MOBILE : LEVEL3_PLOT_SIZE
}

export function preferredLevel3MaxFrames(env = globalThis) {
  return shouldLimitRadarMemory(env) ? LEVEL3_MAX_FRAMES_MOBILE : LEVEL3_MAX_FRAMES
}

/**
 * Load items in parallel batches; keep fulfilled results, skip rejects.
 * On unexpected throw after some successes, revoke blob: URLs first.
 * @template T, R
 * @param {T[]} items
 * @param {(item: T) => Promise<R>} loadFn
 * @param {{ concurrency?: number }} [opts]
 * @returns {Promise<R[]>}
 */
export async function loadFramesWithConcurrency(items, loadFn, { concurrency = 3 } = {}) {
  const frames = []
  try {
    for (let i = 0; i < items.length; i += concurrency) {
      const batch = items.slice(i, i + concurrency)
      const settled = await Promise.allSettled(batch.map((item) => loadFn(item)))
      for (const outcome of settled) {
        if (outcome.status === "fulfilled") {
          frames.push(outcome.value)
        } else {
          console.warn("Level III frame failed", outcome.reason)
        }
      }
    }
    return frames
  } catch (error) {
    revokeLevel3FrameUrls(frames)
    throw error
  }
}

/** Revoke blob object URLs created for Level III frames (best-effort). */
export function revokeLevel3FrameUrls(frames) {
  for (const frame of frames) {
    if (typeof frame?.url === "string" && frame.url.startsWith("blob:")) {
      URL.revokeObjectURL(frame.url)
    }
  }
}

/**
 * After a non-empty S3 listing, require at least one successful frame.
 * Returning [] here would be cached by loadRidgeFrames like a real miss.
 */
export function requireLoadedLevel3Frames(listedCount, frames, { sector, product } = {}) {
  if (frames.length > 0) return frames
  throw new Error(
    `Level III: listed ${listedCount} key(s) for ${sector}/${product} but all frame loads failed`,
  )
}

export function parseLevel3KeyTime(key) {
  // ATX_NAB_2026_07_21_23_08_51
  const match = key.match(/_(\d{4})_(\d{2})_(\d{2})_(\d{2})_(\d{2})_(\d{2})$/)
  if (!match) return null
  const [, y, mo, d, h, mi, s] = match
  return new Date(Date.UTC(+y, +mo - 1, +d, +h, +mi, +s))
}

export function boundsForRadar(lat, lon, rangeKm = LEVEL3_RANGE_KM) {
  const latDelta = rangeKm / 111.32
  const lonDelta = rangeKm / (111.32 * Math.cos((lat * Math.PI) / 180))
  return [
    [lat - latDelta, lon - lonDelta],
    [lat + latDelta, lon + lonDelta],
  ]
}

/** Classic NEXRAD reflectivity palette (approx). */
export function dbzColor(dbz) {
  if (dbz == null || dbz < 5) return null
  if (dbz < 10) return "rgba(4, 233, 231, 0.85)"
  if (dbz < 15) return "rgba(1, 159, 244, 0.85)"
  if (dbz < 20) return "rgba(3, 0, 244, 0.85)"
  if (dbz < 25) return "rgba(2, 253, 2, 0.85)"
  if (dbz < 30) return "rgba(1, 197, 1, 0.85)"
  if (dbz < 35) return "rgba(0, 142, 0, 0.85)"
  if (dbz < 40) return "rgba(253, 248, 2, 0.85)"
  if (dbz < 45) return "rgba(229, 188, 0, 0.85)"
  if (dbz < 50) return "rgba(253, 139, 0, 0.85)"
  if (dbz < 55) return "rgba(212, 0, 0, 0.85)"
  if (dbz < 60) return "rgba(188, 0, 0, 0.9)"
  if (dbz < 65) return "rgba(248, 0, 253, 0.9)"
  if (dbz < 70) return "rgba(153, 85, 201, 0.9)"
  return "rgba(253, 253, 253, 0.95)"
}
