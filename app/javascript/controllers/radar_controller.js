import { Controller } from "@hotwired/stimulus"
import L from "leaflet"
import {
  IEM_TILE_BASE,
  IEM_SUBDOMAINS,
  RAINVIEWER_API,
  CARTO_DARK_URL,
  CARTO_ATTR,
  ESRI_DARK_URL,
  ESRI_ATTR,
  RIDGE_PRODUCT,
  RIDGE_TILTS,
  buildMosaicFrames,
  buildRainviewerFrames,
  boundsForRadius,
  ridgeProductForTilt,
} from "./helpers/radar_layers"
import { boundsForRadar, buildLevel3Frames } from "./helpers/level3_frames"

// Full-viewport radar map: IEM mosaic (default), single-site Unidata Level III
// tilts (KATX/KRTX/KLGX), RainViewer at low zoom when no site is selected.
export default class extends Controller {
  static targets = [
    "map",
    "controls",
    "playPause",
    "playIcon",
    "pauseIcon",
    "timestamp",
    "siteChip",
    "tiltControls",
    "tiltChip",
  ]

  static values = {
    lat: Number,
    lon: Number,
    sites: { type: Array, default: [] },
    wideZoomMax: { type: Number, default: 6 },
  }

  connect() {
    this.playing = true
    this.frameIndex = 0
    this.selectedSiteId = null
    this.selectedTilt = "0.5"
    this.frames = []
    this.tileLayers = []
    this.siteMarkers = new Map()
    this.timer = null
    this.activeMode = null
    this.activeProduct = null
    this.rainviewerCache = null
    // sector:product → { frames } | { promise } for Level III reuse across sites/tilts
    this.level3Cache = new Map()
    this.basemapErrors = 0
    this.syncGeneration = 0

    this.map = L.map(this.mapTarget, {
      zoomControl: true,
      attributionControl: true,
      maxZoom: 11,
      minZoom: 3,
      preferCanvas: true,
    })

    this.addBasemap()

    this.map.fitBounds(boundsForRadius(this.latValue, this.lonValue, 200), {
      padding: [12, 12],
      maxZoom: 8,
    })

    this.addSiteMarkers()

    this.onZoom = () => {
      this.syncMode()
    }
    this.map.on("zoomend", this.onZoom)

    this.resizeObserver = new ResizeObserver(() => {
      if (this.map) this.map.invalidateSize({ animate: false })
    })
    this.resizeObserver.observe(this.mapTarget)

    // Defer size fix until layout settles (mobile address-bar / flex shell).
    requestAnimationFrame(() => {
      this.map.invalidateSize()
      this.bootstrap()
    })
  }

  disconnect() {
    this.syncGeneration += 1
    this.stopTimer()
    this.clearRadarLayers()
    this.disposeLevel3Cache()
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
    if (this.map) {
      this.map.off("zoomend", this.onZoom)
      this.map.remove()
      this.map = null
    }
    this.siteMarkers.clear()
  }

  addBasemap() {
    this.basemap = L.tileLayer(CARTO_DARK_URL, {
      attribution: CARTO_ATTR,
      maxZoom: 11,
      crossOrigin: true,
    })

    this.basemap.on("tileerror", () => {
      this.basemapErrors += 1
      // After a handful of failures, swap to Esri dark gray once.
      if (this.basemapErrors >= 4 && !this.basemapFallback) {
        this.basemapFallback = true
        if (this.map.hasLayer(this.basemap)) this.map.removeLayer(this.basemap)
        L.tileLayer(ESRI_DARK_URL, {
          attribution: ESRI_ATTR,
          maxZoom: 11,
          crossOrigin: true,
        }).addTo(this.map)
      }
    })

    this.basemap.addTo(this.map)
  }

  async bootstrap() {
    // Warm all site×tilt Level III frames in the background so selecting a
    // station (or changing tilt) can reuse cache without waiting on S3.
    this.prefetchAllRidgeFrames()
    await this.syncMode({ force: true })
  }

  // --- UI actions -----------------------------------------------------------

  togglePlayback() {
    this.playing = !this.playing
    this.updatePlaybackUi()
    if (this.playing) {
      this.startTimer()
    } else {
      this.stopTimer()
    }
  }

  selectSite(event) {
    const button = event.currentTarget
    const siteId = button.dataset.siteId || null
    if (siteId && siteId === this.selectedSiteId) {
      this.selectedSiteId = null
    } else {
      this.selectedSiteId = siteId || null
    }
    this.updateSiteUi()
    this.syncMode({ force: true })
  }

  selectTilt(event) {
    const tilt = event.currentTarget.dataset.tilt
    if (!tilt || tilt === this.selectedTilt) return
    this.selectedTilt = tilt
    this.updateTiltUi()
    if (this.selectedSiteId) this.syncMode({ force: true })
  }

  // --- Mode / frames --------------------------------------------------------

  resolveMode() {
    if (this.selectedSiteId) return "ridge"
    if (this.map && this.map.getZoom() <= this.wideZoomMaxValue) return "rainviewer"
    return "mosaic"
  }

  ridgeProduct() {
    return ridgeProductForTilt(this.selectedTilt, RIDGE_PRODUCT)
  }

  async syncMode({ force = false } = {}) {
    const mode = this.resolveMode()
    const product = mode === "ridge" ? this.ridgeProduct() : null
    if (
      !force &&
      mode === this.activeMode &&
      product === this.activeProduct &&
      this.frames.length > 0
    ) {
      return
    }

    const generation = ++this.syncGeneration
    this.stopTimer()
    this.clearRadarLayers()
    this.frames = []

    const site =
      mode === "ridge"
        ? this.sitesValue.find((s) => s.id === this.selectedSiteId)
        : null
    const cachedFrames =
      mode === "ridge" && site
        ? this.level3Cache.get(this.level3CacheKey(site.sector, product))?.frames
        : null
    const cacheHit = Array.isArray(cachedFrames) && cachedFrames.length > 0

    if (this.hasTimestampTarget && !cacheHit) {
      this.timestampTarget.textContent = "Loading…"
    }

    try {
      let frames
      if (mode === "ridge") {
        if (!site) {
          this.selectedSiteId = null
          this.updateSiteUi()
          return this.syncMode({ force: true })
        }
        frames = await this.loadRidgeFrames(site, product)
      } else if (mode === "rainviewer") {
        frames = await this.loadRainviewerFrames()
      } else {
        frames = buildMosaicFrames()
      }

      if (generation !== this.syncGeneration || !this.map) return

      if (frames.length === 0) {
        this.activeMode = null
        this.activeProduct = null
        if (this.hasTimestampTarget) {
          this.timestampTarget.textContent =
            mode === "ridge" ? `No frames for ${this.selectedTilt}°` : "No frames"
        }
        return
      }

      this.activeMode = mode
      this.activeProduct = product
      this.frames = frames
      // Oldest → newest; start at 0 so playback advances through time.
      this.frameIndex = 0
      this.tileLayers = this.frames.map((frame) => this.createFrameLayer(frame))
      this.showFrame(this.frameIndex)

      if (this.playing) this.startTimer()
    } catch (error) {
      if (generation !== this.syncGeneration || !this.map) return
      console.error("Radar sync failed", error)
      this.activeMode = null
      this.activeProduct = null
      this.frames = []
      this.clearRadarLayers()
      if (this.hasTimestampTarget) {
        this.timestampTarget.textContent = "Radar unavailable"
      }
    }
  }

  level3CacheKey(sector, product) {
    return `${sector}:${product}`
  }

  // Single-site tilts use Unidata Level III (IEM RIDGE tiles are N0B-only).
  // Results are cached per sector+product so site/tilt switches reuse downloads.
  async loadRidgeFrames(site, product = this.ridgeProduct()) {
    const key = this.level3CacheKey(site.sector, product)
    const cached = this.level3Cache.get(key)
    if (cached?.frames?.length) return cached.frames
    if (cached?.promise) return cached.promise

    const promise = buildLevel3Frames(site.sector, product, site)
      .then((frames) => {
        const entry = this.level3Cache.get(key)
        if (entry?.promise === promise) {
          this.level3Cache.set(key, { frames })
        } else {
          // Cache was cleared (disconnect) while this load was in flight.
          frames.forEach((frame) => {
            if (frame?.kind === "level3" && frame.url?.startsWith("blob:")) {
              URL.revokeObjectURL(frame.url)
            }
          })
        }
        return frames
      })
      .catch((error) => {
        const entry = this.level3Cache.get(key)
        if (entry?.promise === promise) this.level3Cache.delete(key)
        throw error
      })

    this.level3Cache.set(key, { promise })
    return promise
  }

  // Prefetch every local site × tilt on page load (background, low concurrency).
  prefetchAllRidgeFrames() {
    const jobs = []
    this.sitesValue.forEach((site) => {
      RIDGE_TILTS.forEach((tilt) => {
        jobs.push({ site, product: tilt.product })
      })
    })
    // Prefer default 0.5° (N0B) for each site first.
    jobs.sort(
      (a, b) =>
        (a.product === RIDGE_PRODUCT ? 0 : 1) - (b.product === RIDGE_PRODUCT ? 0 : 1),
    )

    void this.runPrefetchQueue(jobs)
  }

  async runPrefetchQueue(jobs, concurrency = 1) {
    let index = 0
    const workers = Array.from({ length: concurrency }, async () => {
      while (index < jobs.length && this.map) {
        const job = jobs[index]
        index += 1
        try {
          await this.loadRidgeFrames(job.site, job.product)
        } catch (error) {
          console.warn(
            `Radar prefetch failed for ${job.site.sector} ${job.product}`,
            error,
          )
        }
      }
    })
    await Promise.all(workers)
  }

  disposeLevel3Cache() {
    this.level3Cache.forEach((entry) => {
      entry.frames?.forEach((frame) => {
        if (frame?.kind === "level3" && frame.url?.startsWith("blob:")) {
          URL.revokeObjectURL(frame.url)
        }
      })
    })
    this.level3Cache.clear()
  }

  async loadRainviewerFrames() {
    if (!this.rainviewerCache) {
      const response = await fetch(RAINVIEWER_API)
      if (!response.ok) throw new Error(`RainViewer HTTP ${response.status}`)
      this.rainviewerCache = await response.json()
    }
    return buildRainviewerFrames(this.rainviewerCache)
  }

  createFrameLayer(frame) {
    if (frame.kind === "level3") {
      return L.imageOverlay(frame.url, boundsForRadar(frame.lat, frame.lon), {
        opacity: 0,
        interactive: false,
        className: "radar-tile-layer",
        zIndex: 200,
      })
    }

    const common = {
      opacity: 0,
      zIndex: 200,
      maxZoom: 11,
      maxNativeZoom: frame.kind === "rainviewer" ? 7 : 11,
      className: "radar-tile-layer",
    }

    if (frame.kind === "rainviewer") {
      return L.tileLayer(frame.urlTemplate, {
        ...common,
        attribution: 'Radar &copy; <a href="https://www.rainviewer.com/">RainViewer</a>',
      })
    }

    return L.tileLayer(`${IEM_TILE_BASE}/${frame.layer}/{z}/{x}/{y}.png`, {
      ...common,
      subdomains: IEM_SUBDOMAINS,
      attribution: 'Radar data &copy; <a href="https://mesonet.agron.iastate.edu/">IEM</a>',
    })
  }

  clearRadarLayers() {
    // Only detach map layers. Level III blob URLs stay alive in level3Cache
    // so tilt toggles can reuse them without re-downloading.
    this.tileLayers.forEach((layer) => {
      if (this.map && this.map.hasLayer(layer)) this.map.removeLayer(layer)
    })
    this.tileLayers = []
  }

  showFrame(index) {
    if (!this.frames.length) return
    this.frameIndex = ((index % this.frames.length) + this.frames.length) % this.frames.length

    this.tileLayers.forEach((layer, i) => {
      if (!this.map.hasLayer(layer)) layer.addTo(this.map)
      layer.setOpacity(i === this.frameIndex ? 0.7 : 0)
    })

    const frame = this.frames[this.frameIndex]
    if (this.hasTimestampTarget && frame) {
      this.timestampTarget.textContent = frame.label
    }
  }

  advanceFrame() {
    this.showFrame(this.frameIndex + 1)
  }

  startTimer() {
    this.stopTimer()
    if (!this.playing || this.frames.length < 2) return
    this.timer = window.setInterval(() => this.advanceFrame(), 500)
  }

  stopTimer() {
    if (this.timer) {
      window.clearInterval(this.timer)
      this.timer = null
    }
  }

  // --- Markers / chrome -----------------------------------------------------

  addSiteMarkers() {
    this.sitesValue.forEach((site) => {
      const icon = L.divIcon({
        className: "radar-marker",
        html: `<button type="button" class="radar-marker-site" data-site-id="${site.id}" aria-label="${site.id} ${site.name}"><span class="radar-marker-site-label">${site.sector}</span></button>`,
        iconSize: [44, 44],
        iconAnchor: [22, 22],
      })
      const marker = L.marker([site.lat, site.lon], { icon, keyboard: true })
        .addTo(this.map)
        .bindTooltip(`${site.id} — ${site.name}`, { direction: "top", offset: [0, -18] })

      marker.on("click", () => {
        if (this.selectedSiteId === site.id) {
          this.selectedSiteId = null
        } else {
          this.selectedSiteId = site.id
        }
        this.updateSiteUi()
        this.syncMode({ force: true })
      })

      this.siteMarkers.set(site.id, marker)
    })
  }

  updateSiteUi() {
    if (this.hasSiteChipTarget) {
      this.siteChipTargets.forEach((chip) => {
        const id = chip.dataset.siteId || ""
        const active = id === (this.selectedSiteId || "")
        chip.classList.toggle("is-active", active)
        chip.setAttribute("aria-pressed", active ? "true" : "false")
      })
    }

    this.siteMarkers.forEach((marker, id) => {
      const el = marker.getElement()?.querySelector(".radar-marker-site")
      if (el) el.classList.toggle("is-active", id === this.selectedSiteId)
    })

    this.updateTiltUi()
  }

  updateTiltUi() {
    if (this.hasTiltControlsTarget) {
      this.tiltControlsTarget.classList.toggle("hidden", !this.selectedSiteId)
    }

    if (this.hasTiltChipTarget) {
      this.tiltChipTargets.forEach((chip) => {
        const active = chip.dataset.tilt === this.selectedTilt
        chip.classList.toggle("is-active", active)
        chip.setAttribute("aria-pressed", active ? "true" : "false")
      })
    }
  }

  updatePlaybackUi() {
    if (this.hasPlayIconTarget && this.hasPauseIconTarget) {
      this.playIconTarget.classList.toggle("hidden", this.playing)
      this.pauseIconTarget.classList.toggle("hidden", !this.playing)
    }
    if (this.hasPlayPauseTarget) {
      this.playPauseTarget.setAttribute(
        "aria-label",
        this.playing ? "Pause radar animation" : "Play radar animation",
      )
    }
  }
}
