// Pure helpers for building LibreWXR radar / satellite frame lists.

export const LIBREWXR_DEFAULT_HOST = "https://api.librewxr.net"
/** NEXRAD Level III scheme — closest built-in match to the site rain ladder. */
export const LIBREWXR_COLOR_SCHEME = 6
export const LIBREWXR_OPTIONS_SNOW = "1_1"
export const LIBREWXR_OPTIONS_NOSNOW = "1_0"
export const LIBREWXR_MAX_NATIVE_ZOOM = 12
export const LIBREWXR_METADATA_TTL_MS = 3 * 60 * 1000
export const LIBREWXR_ALERTS_TTL_MS = 5 * 60 * 1000

/** Default RIDGE product: super-res base reflectivity at ~0.5°. */
export const RIDGE_PRODUCT = "N0B"

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

export const LIBREWXR_ATTR =
  'Radar & satellite &copy; <a href="https://librewxr.net/">LibreWXR</a> (MRMS/NOAA, NWP)'

/** Normalize a configured LibreWXR base (host or full metadata URL) to origin. */
export function normalizeLibreWxrHost(base = LIBREWXR_DEFAULT_HOST) {
  const trimmed = String(base || LIBREWXR_DEFAULT_HOST).trim().replace(/\/$/, "")
  if (trimmed.endsWith("/public/weather-maps.json")) {
    return trimmed.slice(0, -"/public/weather-maps.json".length) || LIBREWXR_DEFAULT_HOST
  }
  return trimmed || LIBREWXR_DEFAULT_HOST
}

export function librewxrMetadataUrl(base = LIBREWXR_DEFAULT_HOST) {
  return `${normalizeLibreWxrHost(base)}/public/weather-maps.json`
}

export function librewxrAlertsUrl(base, { lat, lon, bbox } = {}) {
  const host = normalizeLibreWxrHost(base)
  const url = new URL(`${host}/v2/alerts`)
  if (bbox) {
    url.searchParams.set("bbox", bbox)
  } else if (lat != null && lon != null) {
    url.searchParams.set("lat", String(lat))
    url.searchParams.set("lon", String(lon))
  }
  return url.toString()
}

/**
 * Prefer the app-configured LibreWXR origin for tile URLs so custom hosts
 * are not overridden by the `host` field inside weather-maps.json.
 */
export function resolveLibreWxrTileHost(api, tileHost) {
  return normalizeLibreWxrHost(tileHost || api?.host || LIBREWXR_DEFAULT_HOST)
}

/**
 * Build LibreWXR radar frames (past + optional nowcast) from weather-maps.json.
 * @param {{ host?: string, radar?: { past?: { time: number, path: string }[], nowcast?: { time: number, path: string }[] } }} api
 */
export function buildLibreWxrRadarFrames(
  api,
  {
    size = 256,
    color = LIBREWXR_COLOR_SCHEME,
    options = LIBREWXR_OPTIONS_SNOW,
    arrows = "light",
    includeNowcast = true,
    tileHost,
  } = {},
) {
  const host = resolveLibreWxrTileHost(api, tileHost)
  const past = api.radar?.past || []
  const nowcast = includeNowcast ? api.radar?.nowcast || [] : []
  const arrowQs = arrows ? `?arrows=${encodeURIComponent(arrows)}` : ""

  const toFrame = (frame, isNowcast) => {
    const time = new Date(frame.time * 1000)
    const timeLabel = formatFrameTime(time)
    return {
      id: `lw-${isNowcast ? "nc" : "past"}-${frame.time}`,
      label: isNowcast ? `Nowcast · ${timeLabel}` : timeLabel,
      urlTemplate: `${host}${frame.path}/${size}/{z}/{x}/{y}/${color}/${options}.png${arrowQs}`,
      time,
      kind: "librewxr",
      isNowcast,
    }
  }

  return [...past.map((frame) => toFrame(frame, false)), ...nowcast.map((frame) => toFrame(frame, true))]
}

/**
 * Build LibreWXR GMGSI satellite frames from weather-maps.json.
 * @param {{ host?: string, satellite?: { infrared?: { time: number, path: string }[] } }} api
 */
export function buildLibreWxrSatelliteFrames(api, { size = 256, tileHost } = {}) {
  const host = resolveLibreWxrTileHost(api, tileHost)
  const frames = api.satellite?.infrared || []
  return frames.map((frame) => {
    const time = new Date(frame.time * 1000)
    return {
      id: `lw-sat-${frame.time}`,
      label: formatFrameTime(time),
      urlTemplate: `${host}${frame.path}/${size}/{z}/{x}/{y}/0/0_0.png`,
      time,
      kind: "librewxr-satellite",
      isNowcast: false,
    }
  })
}

/**
 * Pick a frame index after a metadata refresh so playback does not jump to 0.
 * Prefers an exact id match, otherwise the latest frame at or before the prior time.
 */
export function resolvePreservedFrameIndex(frames, previousFrame) {
  if (!previousFrame || !Array.isArray(frames) || frames.length === 0) return 0

  const byId = frames.findIndex((frame) => frame.id === previousFrame.id)
  if (byId >= 0) return byId

  const previousTime = previousFrame.time?.getTime?.()
  if (previousTime == null) return 0

  let best = 0
  for (let i = 0; i < frames.length; i += 1) {
    const time = frames[i].time?.getTime?.()
    if (time != null && time <= previousTime) best = i
    else if (time != null && time > previousTime) break
  }
  return best
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

/** Severity → Leaflet path style for alert polygons. */
export function alertPathStyle(severity) {
  const key = String(severity || "").toLowerCase()
  if (key === "extreme") {
    return { color: "#f43f5e", fillColor: "#f43f5e", fillOpacity: 0.22, weight: 2 }
  }
  if (key === "severe") {
    return { color: "#f97316", fillColor: "#f97316", fillOpacity: 0.2, weight: 2 }
  }
  if (key === "moderate") {
    return { color: "#eab308", fillColor: "#eab308", fillOpacity: 0.18, weight: 2 }
  }
  return { color: "#38bdf8", fillColor: "#38bdf8", fillOpacity: 0.15, weight: 1.5 }
}

export function alertPopupHtml(properties = {}) {
  const title = escapeHtml(properties.title || properties.event || "Weather alert")
  const severity = escapeHtml(properties.severity || "Unknown")
  const description = escapeHtml(properties.description || "").replace(/\n/g, "<br>")
  const expires = properties.expires
    ? escapeHtml(formatFrameTime(new Date(properties.expires * 1000)))
    : null
  const parts = [
    `<strong>${title}</strong>`,
    `<div class="radar-alert-meta">Severity: ${severity}</div>`,
  ]
  if (expires) parts.push(`<div class="radar-alert-meta">Expires: ${expires}</div>`)
  if (description) parts.push(`<div class="radar-alert-body">${description}</div>`)
  return parts.join("")
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}
