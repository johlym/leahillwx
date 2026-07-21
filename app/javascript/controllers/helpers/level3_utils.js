/** Super-res base reflectivity range (~248 nmi). */
export const LEVEL3_RANGE_KM = 460

/** Full native plot resolution (~248 nmi diameter at 0.25 mi/bin). */
export const LEVEL3_PLOT_SIZE = 1800

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
