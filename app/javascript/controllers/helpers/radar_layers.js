// Pure helpers for building radar tile frame lists (IEM + RainViewer).

export const IEM_TILE_BASE = "https://mesonet{s}.agron.iastate.edu/cache/tile.py/1.0.0"
// Empty string hits mesonet.agron.iastate.edu; 1/2/3 are CDN aliases.
export const IEM_SUBDOMAINS = ["", "1", "2", "3"]
export const RAINVIEWER_API = "https://api.rainviewer.com/public/weather-maps.json"
/** Default RIDGE product: super-res base reflectivity at ~0.5°. */
export const RIDGE_PRODUCT = "N0B"
export const MOSAIC_LAYER = "nexrad-n0q"

/**
 * Single-site reflectivity tilts (elevation angle → Level III product).
 * Labels use common display degrees; NAB is officially ~0.9°.
 */
export const RIDGE_TILTS = [
  { degrees: "0.5", product: "N0B", label: "0.5°" },
  { degrees: "1.0", product: "NAB", label: "1.0°" },
  { degrees: "1.5", product: "N1B", label: "1.5°" },
]

export function ridgeProductForTilt(degrees, fallback = RIDGE_PRODUCT) {
  const match = RIDGE_TILTS.find((tilt) => tilt.degrees === String(degrees))
  return match?.product || fallback
}

/** Primary dark basemap (CARTO). Avoid a/b/c/d letter subdomains — some
 * resolvers only answer the apex basemaps.cartocdn.com host. */
export const CARTO_DARK_URL = "https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
export const CARTO_ATTR =
  '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> &copy; <a href="https://carto.com/attributions">CARTO</a>'

/** Fallback dark basemap (Esri). Note z/y/x order. */
export const ESRI_DARK_URL =
  "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}"
export const ESRI_ATTR = "Tiles &copy; Esri"

/** Relative mosaic offsets (minutes ago), oldest → newest, plus current. */
export const MOSAIC_OFFSETS = [55, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5, 0]

/**
 * Build IEM CONUS mosaic animation frames (nexrad-n0q + mXXm).
 * @returns {{ id: string, label: string, layer: string, time: Date|null }[]}
 */
export function buildMosaicFrames(now = new Date()) {
  return MOSAIC_OFFSETS.map((offset) => {
    const layer = offset === 0 ? MOSAIC_LAYER : `${MOSAIC_LAYER}-m${String(offset).padStart(2, "0")}m`
    const time = new Date(now.getTime() - offset * 60_000)
    return {
      id: `mosaic-${offset}`,
      label: formatFrameTime(time),
      layer,
      time,
      kind: "iem",
    }
  })
}

/**
 * Build IEM RIDGE single-site frames from /json/radar.py list response.
 * @param {string} sector e.g. "ATX"
 * @param {{ ts: string }[]} scans
 */
export function buildRidgeFrames(sector, scans, product = RIDGE_PRODUCT) {
  return scans.map((scan) => {
    const time = new Date(scan.ts.endsWith("Z") ? scan.ts : `${scan.ts}Z`)
    const stamp = toIemTimestamp(time)
    return {
      id: `ridge-${sector}-${stamp}`,
      label: formatFrameTime(time),
      layer: `ridge::${sector}-${product}-${stamp}`,
      time,
      kind: "iem",
    }
  })
}

/**
 * Build RainViewer frames from weather-maps.json payload.
 * @param {{ host: string, radar?: { past?: { time: number, path: string }[] } }} api
 */
export function buildRainviewerFrames(api, { size = 256, color = 2, options = "1_1" } = {}) {
  const host = api.host?.replace(/\/$/, "") || "https://tilecache.rainviewer.com"
  const past = api.radar?.past || []
  return past.map((frame) => {
    const time = new Date(frame.time * 1000)
    return {
      id: `rv-${frame.time}`,
      label: formatFrameTime(time),
      // Leaflet template; RainViewer path already includes /v2/radar/...
      urlTemplate: `${host}${frame.path}/${size}/{z}/{x}/{y}/${color}/${options}.png`,
      time,
      kind: "rainviewer",
    }
  })
}

/** Bounds roughly covering `radiusMiles` around a point. */
export function boundsForRadius(lat, lon, radiusMiles = 200) {
  const latDelta = radiusMiles / 69
  const lonDelta = radiusMiles / (Math.cos((lat * Math.PI) / 180) * 69)
  return [
    [lat - latDelta, lon - lonDelta],
    [lat + latDelta, lon + lonDelta],
  ]
}

export function toIemTimestamp(date) {
  const y = date.getUTCFullYear()
  const m = String(date.getUTCMonth() + 1).padStart(2, "0")
  const d = String(date.getUTCDate()).padStart(2, "0")
  const h = String(date.getUTCHours()).padStart(2, "0")
  const mi = String(date.getUTCMinutes()).padStart(2, "0")
  return `${y}${m}${d}${h}${mi}`
}

export function formatFrameTime(date) {
  try {
    return new Intl.DateTimeFormat("en-US", {
      timeZone: "America/Los_Angeles",
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
      timeZoneName: "short",
    }).format(date)
  } catch {
    return date.toISOString()
  }
}

export function ridgeListUrl(sector, start, end, product = RIDGE_PRODUCT) {
  const params = new URLSearchParams({
    operation: "list",
    radar: sector,
    product,
    start: toIsoMinute(start),
    end: toIsoMinute(end),
  })
  return `https://mesonet.agron.iastate.edu/json/radar.py?${params}`
}

function toIsoMinute(date) {
  const y = date.getUTCFullYear()
  const m = String(date.getUTCMonth() + 1).padStart(2, "0")
  const d = String(date.getUTCDate()).padStart(2, "0")
  const h = String(date.getUTCHours()).padStart(2, "0")
  const mi = String(date.getUTCMinutes()).padStart(2, "0")
  return `${y}-${m}-${d}T${h}:${mi}Z`
}
