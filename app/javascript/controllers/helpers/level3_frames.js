// Unidata Level III reflectivity (N0B/NAB/N1B) → Leaflet image overlays.
// IEM RIDGE tiles only archive N0B; higher tilts come from s3://unidata-nexrad-level3.

import { Buffer } from "buffer"
import parseLevel3 from "nexrad-level-3-data"
import { formatFrameTime } from "./radar_layers"
import {
  LEVEL3_PLOT_SIZE,
  LEVEL3_RANGE_KM,
  boundsForRadar,
  dbzColor,
  loadFramesWithConcurrency,
  parseLevel3KeyTime,
  preferredLevel3MaxFrames,
  preferredLevel3PlotSize,
  requireLoadedLevel3Frames,
  revokeLevel3FrameUrls,
} from "./level3_utils"

export {
  LEVEL3_PLOT_SIZE,
  LEVEL3_RANGE_KM,
  boundsForRadar,
  dbzColor,
  loadFramesWithConcurrency,
  parseLevel3KeyTime,
  preferredLevel3MaxFrames,
  preferredLevel3PlotSize,
  requireLoadedLevel3Frames,
  revokeLevel3FrameUrls,
}

export const LEVEL3_S3_BASE = "https://unidata-nexrad-level3.s3.amazonaws.com"

/**
 * List recent Level III keys for a sector + product (oldest → newest).
 * @param {string} sector e.g. "ATX"
 * @param {string} product e.g. "NAB"
 * @param {{ hours?: number, now?: Date }} [opts]
 */
export async function listLevel3Keys(sector, product, { hours = 1.5, now = new Date() } = {}) {
  const end = now
  const start = new Date(end.getTime() - hours * 3_600_000)
  const days = uniqueUtcDays(start, end)
  const keys = []

  for (const day of days) {
    const prefix = `${sector}_${product}_${day}`
    let token = null
    do {
      const url = new URL(LEVEL3_S3_BASE)
      url.searchParams.set("list-type", "2")
      url.searchParams.set("prefix", prefix)
      url.searchParams.set("max-keys", "1000")
      if (token) url.searchParams.set("continuation-token", token)

      const response = await fetch(url)
      if (!response.ok) throw new Error(`Level III list HTTP ${response.status}`)
      const xml = await response.text()
      keys.push(...parseS3Keys(xml))
      token = parseS3Continuation(xml)
    } while (token)
  }

  return keys
    .map((key) => ({ key, time: parseLevel3KeyTime(key) }))
    .filter((frame) => frame.time && frame.time >= start && frame.time <= end)
    .sort((a, b) => a.time - b.time)
}

/**
 * Fetch, parse, and rasterize one Level III file to a PNG object URL.
 */
export async function loadLevel3Frame(key, { size = LEVEL3_PLOT_SIZE } = {}) {
  const response = await fetch(`${LEVEL3_S3_BASE}/${key}`)
  if (!response.ok) throw new Error(`Level III fetch HTTP ${response.status}`)
  // nexrad-level-3-data's RandomAccessFile requires a Node Buffer (readIntBE, etc).
  const buffer = Buffer.from(await response.arrayBuffer())
  const data = parseLevel3(buffer)
  const time = parseLevel3KeyTime(key) || productTime(data)
  const canvas = plotReflectivity(data, { size })
  const url = await canvasToObjectUrl(canvas)

  return {
    id: key,
    key,
    url,
    time,
    label: formatFrameTime(time),
    lat: data.productDescription.latitude,
    lon: data.productDescription.longitude,
    elevationAngle: data.productDescription.elevationAngle,
    kind: "level3",
  }
}

/**
 * Build oldest→newest frame list (metadata + rendered URLs).
 * Individual scan failures are skipped so one bad S3 object does not
 * blank the whole site/tilt. If S3 listed keys but every load failed,
 * throw so callers do not cache [] as a permanent "no scans" hit.
 * Unexpected aborts revoke any blob URLs already created for this call.
 */
export async function buildLevel3Frames(sector, product, site, opts = {}) {
  const keys = await listLevel3Keys(sector, product, opts)
  // Genuine empty listing — safe to cache as "no scans for this product".
  if (keys.length === 0) return []

  const size = opts.size ?? preferredLevel3PlotSize()
  const maxFrames = opts.maxFrames ?? preferredLevel3MaxFrames()
  const sampled = sampleFrames(keys, maxFrames)
  const frames = await loadFramesWithConcurrency(sampled, (item) =>
    loadLevel3Frame(item.key, { ...opts, size }),
  )
  requireLoadedLevel3Frames(sampled.length, frames, { sector, product })

  return frames.map((frame) => ({
    ...frame,
    lat: frame.lat || site.lat,
    lon: frame.lon || site.lon,
  }))
}

export function plotReflectivity(data, { size = LEVEL3_PLOT_SIZE } = {}) {
  const packet = data.radialPackets?.[0]
  if (!packet?.radials?.length) throw new Error("No radial reflectivity data")

  const canvas = document.createElement("canvas")
  canvas.width = size
  canvas.height = size
  const ctx = canvas.getContext("2d")
  ctx.clearRect(0, 0, size, size)
  ctx.imageSmoothingEnabled = true
  ctx.lineWidth = 2
  ctx.translate(size / 2, size / 2)
  ctx.rotate(-Math.PI / 2)

  // Match nexrad-level-3-plot: 1800px ≈ full 248 nmi diameter at 0.25 mi/bin.
  const scale = 1800 / size
  const maxBin = Math.min(packet.numberBins, Math.ceil(900 * scale))

  packet.radials.forEach((radial) => {
    const startAngle = radial.startAngle * (Math.PI / 180)
    const endAngle = startAngle + radial.angleDelta * (Math.PI / 180)
    let maxDownsample = 0
    let lastRemainder = 0

    for (let idx = 0; idx < maxBin; idx += 1) {
      const bin = radial.bins[idx]
      if (bin == null) continue

      let sample = null
      if (scale !== 1) {
        const remainder = idx % scale
        if (remainder < lastRemainder) {
          sample = maxDownsample
          maxDownsample = 0
        }
        maxDownsample = Math.max(bin, maxDownsample)
        lastRemainder = remainder
      } else {
        sample = bin
      }

      if (sample == null || sample < 5) continue
      const color = dbzColor(sample)
      if (!color) continue
      ctx.beginPath()
      ctx.strokeStyle = color
      ctx.arc(0, 0, (idx + packet.firstBin) / scale, startAngle, endAngle)
      ctx.stroke()
    }
  })

  return canvas
}

function sampleFrames(frames, maxFrames) {
  if (frames.length <= maxFrames) return frames
  const out = []
  const step = (frames.length - 1) / (maxFrames - 1)
  for (let i = 0; i < maxFrames; i += 1) {
    out.push(frames[Math.round(i * step)])
  }
  return out
}

function uniqueUtcDays(start, end) {
  const days = []
  const cursor = new Date(Date.UTC(start.getUTCFullYear(), start.getUTCMonth(), start.getUTCDate()))
  const last = new Date(Date.UTC(end.getUTCFullYear(), end.getUTCMonth(), end.getUTCDate()))
  while (cursor <= last) {
    const y = cursor.getUTCFullYear()
    const m = String(cursor.getUTCMonth() + 1).padStart(2, "0")
    const d = String(cursor.getUTCDate()).padStart(2, "0")
    days.push(`${y}_${m}_${d}`)
    cursor.setUTCDate(cursor.getUTCDate() + 1)
  }
  return days
}

function parseS3Keys(xml) {
  const keys = []
  const re = /<Key>([^<]+)<\/Key>/g
  let match
  while ((match = re.exec(xml))) keys.push(match[1])
  return keys
}

function parseS3Continuation(xml) {
  if (!xml.includes("<IsTruncated>true</IsTruncated>")) return null
  const match = xml.match(/<NextContinuationToken>([^<]+)<\/NextContinuationToken>/)
  return match ? match[1] : null
}

function productTime(data) {
  const date = data.productDescription?.productDate
  const time = data.productDescription?.productTime
  if (date == null || time == null) return new Date()
  const ms = (date - 1) * 86_400_000 + time * 1000
  return new Date(ms)
}

function canvasToObjectUrl(canvas) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (!blob) {
          reject(new Error("Failed to encode radar frame"))
          return
        }
        resolve(URL.createObjectURL(blob))
      },
      "image/png",
    )
  })
}
