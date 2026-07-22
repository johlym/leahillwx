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
 * NWS-style reflectivity ladder (5 dBZ steps), matching the HVY / MOD / LGT / VLGT
 * legend. Each entry is the color for [dbz, next) — ND / below -30 is transparent.
 * Colors are approximate RGB sampled from the standard NWS scale.
 */
export const DBZ_PALETTE = [
  { dbz: -30, rgba: "rgba(170, 210, 230, 0.75)" }, // pale cyan — VLGT
  { dbz: -25, rgba: "rgba(210, 170, 210, 0.75)" }, // lavender
  { dbz: -20, rgba: "rgba(150, 90, 170, 0.8)" }, // muted purple
  { dbz: -15, rgba: "rgba(110, 40, 120, 0.8)" }, // dark plum
  { dbz: -10, rgba: "rgba(200, 180, 140, 0.8)" }, // light tan
  { dbz: -5, rgba: "rgba(150, 145, 95, 0.8)" }, // olive grey/tan
  { dbz: 0, rgba: "rgba(95, 95, 95, 0.75)" }, // dark grey
  { dbz: 5, rgba: "rgba(90, 235, 245, 0.85)" }, // light cyan — LGT
  { dbz: 10, rgba: "rgba(40, 160, 255, 0.85)" }, // sky blue
  { dbz: 15, rgba: "rgba(0, 0, 255, 0.85)" }, // blue
  { dbz: 20, rgba: "rgba(0, 255, 0, 0.85)" }, // bright lime green
  { dbz: 25, rgba: "rgba(0, 200, 0, 0.85)" }, // medium green
  { dbz: 30, rgba: "rgba(0, 140, 0, 0.85)" }, // dark green
  { dbz: 35, rgba: "rgba(255, 255, 0, 0.85)" }, // yellow — MOD
  { dbz: 40, rgba: "rgba(255, 200, 0, 0.85)" }, // golden yellow
  { dbz: 45, rgba: "rgba(255, 140, 0, 0.85)" }, // orange
  { dbz: 50, rgba: "rgba(255, 80, 80, 0.9)" }, // light red
  { dbz: 55, rgba: "rgba(255, 0, 0, 0.9)" }, // red
  { dbz: 60, rgba: "rgba(180, 0, 0, 0.9)" }, // deep red
  { dbz: 65, rgba: "rgba(255, 0, 200, 0.95)" }, // magenta — HVY
  { dbz: 70, rgba: "rgba(150, 0, 255, 0.95)" }, // purple
  { dbz: 75, rgba: "rgba(255, 255, 255, 0.95)" }, // white
]

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

/**
 * Map a reflectivity sample to an RGBA color.
 * ND / missing / below -30 dBZ → transparent (null).
 */
export function dbzColor(dbz) {
  if (dbz == null || Number.isNaN(dbz) || dbz < -30) return null

  let color = DBZ_PALETTE[0].rgba
  for (const step of DBZ_PALETTE) {
    if (dbz >= step.dbz) color = step.rgba
    else break
  }
  return color
}
