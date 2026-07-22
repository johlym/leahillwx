import { Controller } from "@hotwired/stimulus"
import L from "leaflet"
import {
  LIBREWXR_DEFAULT_HOST,
  LIBREWXR_OPTIONS_SNOW,
  LIBREWXR_OPTIONS_NOSNOW,
  LIBREWXR_MAX_NATIVE_ZOOM,
  LIBREWXR_METADATA_TTL_MS,
  LIBREWXR_ATTR,
  CARTO_DARK_URL,
  CARTO_ATTR,
  ESRI_DARK_URL,
  ESRI_ATTR,
  RIDGE_PRODUCT,
  RIDGE_TILTS,
  librewxrMetadataUrl,
  buildLibreWxrRadarFrames,
  buildLibreWxrSatelliteFrames,
  resolvePreservedFrameIndex,
  boundsForRadius,
  ridgeProductForTilt,
} from "./helpers/radar_layers"
import { boundsForRadar, buildLevel3Frames } from "./helpers/level3_frames"
import { shouldLimitRadarMemory } from "./helpers/level3_utils"

// Full-viewport radar map: LibreWXR composite (precip / cloud / nowcast),
// single-site Unidata Level III tilts (KATX/KRTX/KLGX).
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
    "layerControls",
    "layerChip",
    "optionChip",
  ]

  static values = {
    lat: Number,
    lon: Number,
    sites: { type: Array, default: [] },
    librewxrHost: { type: String, default: LIBREWXR_DEFAULT_HOST },
  }

  connect() {
    this.playing = true
    this.frameIndex = 0
    this.selectedSiteId = null
    this.selectedTilt = "0.5"
    this.compositeLayer = "precip" // precip | cloud
    this.snowColorsEnabled = true
    this.frames = []
    this.tileLayers = []
    this.siteMarkers = new Map()
    this.timer = null
    this.metadataTimer = null
    this.activeMode = null
    this.activeProduct = null
    this.activeCompositeLayer = null
    this.librewxrCache = null
    this.librewxrCacheAt = 0
    this.librewxrFetchPromise = null
    this.librewxrRefreshPromise = null
    this.pendingQuietRefresh = null
    this.zooming = false
    // sector:product → { frames } | { promise } for Level III reuse across sites/tilts
    this.level3Cache = new Map()
    this.basemapErrors = 0
    this.syncGeneration = 0
    this.limitMemory = shouldLimitRadarMemory()
    // High zoom × many tile layers OOMs mobile Safari; keep desktop detail.
    this.mapMaxZoom = this.limitMemory ? 9 : Math.min(11, LIBREWXR_MAX_NATIVE_ZOOM)

    this.map = L.map(this.mapTarget, {
      zoomControl: true,
      attributionControl: true,
      maxZoom: this.mapMaxZoom,
      minZoom: 3,
      preferCanvas: true,
      // Skip CSS fade on tile panes — cheaper while dragging/zooming.
      fadeAnimation: false,
    })

    this.addBasemap()

    this.map.fitBounds(boundsForRadius(this.latValue, this.lonValue, 200), {
      padding: [12, 12],
      maxZoom: Math.min(8, this.mapMaxZoom),
    })

    this.addSiteMarkers()

    this.onZoomStart = () => {
      // Avoid animating (add/remove layers) while the user is pinching.
      this.zooming = true
      this.stopTimer()
    }
    this.onZoomEnd = () => {
      this.zooming = false
      // Quiet metadata refresh may have finished mid-pinch; apply the swap now.
      this.flushPendingQuietRefresh()
      if (this.playing) this.startTimer()
    }
    this.onDragStart = () => {
      this.stopTimer()
    }
    this.onDragEnd = () => {
      if (this.playing && !this.zooming) this.startTimer()
    }
    this.map.on("zoomstart", this.onZoomStart)
    this.map.on("zoomend", this.onZoomEnd)
    this.map.on("dragstart", this.onDragStart)
    this.map.on("dragend", this.onDragEnd)

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
    this.pendingQuietRefresh = null
    this.zooming = false
    this.stopTimer()
    this.stopMetadataRefresh()
    this.clearRadarLayers()
    this.disposeLevel3Cache()
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
    if (this.map) {
      this.map.off("zoomstart", this.onZoomStart)
      this.map.off("zoomend", this.onZoomEnd)
      this.map.off("dragstart", this.onDragStart)
      this.map.off("dragend", this.onDragEnd)
      this.map.remove()
      this.map = null
    }
    this.siteMarkers.clear()
  }

  addBasemap() {
    this.basemap = L.tileLayer(CARTO_DARK_URL, {
      attribution: CARTO_ATTR,
      maxZoom: this.mapMaxZoom,
      keepBuffer: 1,
      updateWhenIdle: true,
      updateWhenZooming: false,
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
          maxZoom: this.mapMaxZoom,
          keepBuffer: 1,
          updateWhenIdle: true,
          updateWhenZooming: false,
          crossOrigin: true,
        }).addTo(this.map)
      }
    })

    this.basemap.addTo(this.map)
  }

  async bootstrap() {
    this.updateLayerUi()
    this.updateOptionUi()
    // Desktop: warm site×tilt Level III in the background. Skip on mobile —
    // prefetching ~9 products of 1800px canvases is a common tab-killer.
    if (!this.limitMemory) this.prefetchAllRidgeFrames()
    await this.syncMode({ force: true })
    this.startMetadataRefresh()
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
    this.updateLayerUi()
    this.syncMode({ force: true })
  }

  selectTilt(event) {
    const tilt = event.currentTarget.dataset.tilt
    if (!tilt || tilt === this.selectedTilt) return
    this.selectedTilt = tilt
    this.updateTiltUi()
    if (this.selectedSiteId) this.syncMode({ force: true })
  }

  selectLayer(event) {
    const layer = event.currentTarget.dataset.layer
    if (!layer || layer === this.compositeLayer || this.selectedSiteId) return
    this.compositeLayer = layer
    this.updateLayerUi()
    this.updateOptionUi()
    this.syncMode({ force: true })
  }

  toggleOption(event) {
    const option = event.currentTarget.dataset.option
    if (option !== "snow") return
    if (this.selectedSiteId || this.compositeLayer !== "precip") return

    this.snowColorsEnabled = !this.snowColorsEnabled
    this.updateOptionUi()
    this.syncMode({ force: true })
  }

  // --- Mode / frames --------------------------------------------------------

  resolveMode() {
    if (this.selectedSiteId) return "ridge"
    return "librewxr"
  }

  ridgeProduct() {
    return ridgeProductForTilt(this.selectedTilt, RIDGE_PRODUCT)
  }

  async syncMode({ force = false, preserveFrame = false } = {}) {
    const mode = this.resolveMode()
    const product = mode === "ridge" ? this.ridgeProduct() : null
    const compositeLayer = mode === "librewxr" ? this.compositeLayer : null
    if (
      !force &&
      mode === this.activeMode &&
      product === this.activeProduct &&
      compositeLayer === this.activeCompositeLayer &&
      this.frames.length > 0
    ) {
      return
    }

    // Quiet metadata refresh: keep composite layers mounted/animating until the
    // replacement set is ready, then swap. Avoids a blank map every ~3 minutes.
    const canPreserve =
      preserveFrame &&
      mode === "librewxr" &&
      this.activeMode === "librewxr" &&
      this.frames.length > 0 &&
      this.tileLayers.length > 0

    const previousLayers = canPreserve ? [...this.tileLayers] : null

    const generation = ++this.syncGeneration
    if (!canPreserve) {
      this.pendingQuietRefresh = null
      this.stopTimer()
      this.clearRadarLayers()
      this.frames = []
    }

    const site =
      mode === "ridge"
        ? this.sitesValue.find((s) => s.id === this.selectedSiteId)
        : null
    const cachedFrames =
      mode === "ridge" && site
        ? this.level3Cache.get(this.level3CacheKey(site.sector, product))?.frames
        : null
    // Empty arrays are valid cache hits (no usable scans for this product).
    const cacheHit = Array.isArray(cachedFrames)

    // Quiet refresh: keep the current timestamp visible while new frames load.
    if (!cacheHit && !canPreserve) {
      this.setTimestamp("Loading…")
    }

    try {
      let frames
      if (mode === "ridge") {
        if (!site) {
          this.selectedSiteId = null
          this.updateSiteUi()
          this.updateLayerUi()
          return this.syncMode({ force: true })
        }
        frames = await this.loadRidgeFrames(site, product)
      } else {
        frames = await this.loadLibreWxrFrames()
      }

      if (generation !== this.syncGeneration || !this.map) return

      if (frames.length === 0) {
        this.pendingQuietRefresh = null
        this.stopTimer()
        this.clearRadarLayers()
        this.frames = []
        this.activeMode = null
        this.activeProduct = null
        this.activeCompositeLayer = null
        let message = "No frames"
        if (mode === "ridge") message = `No frames for ${this.selectedTilt}°`
        else if (this.compositeLayer === "cloud") message = "Cloud unavailable"
        this.setTimestamp(message)
        return
      }

      // Defer quiet swaps during pinch-zoom so we do not add/remove tile layers mid-gesture.
      if (canPreserve && this.zooming) {
        this.pendingQuietRefresh = {
          frames,
          generation,
          mode,
          product,
          compositeLayer,
          previousLayers,
        }
        return
      }

      await this.commitFrameSet({
        frames,
        mode,
        product,
        compositeLayer,
        previousLayers,
        preserve: canPreserve,
        generation,
      })
    } catch (error) {
      if (generation !== this.syncGeneration || !this.map) return
      console.error("Radar sync failed", error)
      if (canPreserve) {
        // Failed quiet refresh: leave the previous composite playing.
        if (this.playing && !this.zooming) this.startTimer()
        return
      }
      this.activeMode = null
      this.activeProduct = null
      this.activeCompositeLayer = null
      this.frames = []
      this.clearRadarLayers()
      this.setTimestamp(
        this.compositeLayer === "cloud" && mode === "librewxr"
          ? "Cloud unavailable"
          : "Radar unavailable",
      )
    }
  }

  /**
   * Apply a loaded frame set.
   * Initial loads: freeze on the newest frame, warm the rest, then animate from oldest.
   * Quiet refreshes: preserve playback index and resume immediately.
   */
  async commitFrameSet({
    frames,
    mode,
    product,
    compositeLayer,
    previousLayers,
    preserve,
    generation = this.syncGeneration,
  }) {
    if (!this.map || !frames?.length) return

    this.stopTimer()
    // Capture before replacing this.frames (quiet refresh keeps old list until now).
    const anchorFrame = preserve ? this.frames[this.frameIndex] : null
    const nextLayers = frames.map((frame) => this.createFrameLayer(frame))
    this.activeMode = mode
    this.activeProduct = product
    this.activeCompositeLayer = compositeLayer
    this.frames = frames
    this.tileLayers = nextLayers
    this.frameIndex = preserve
      ? resolvePreservedFrameIndex(frames, anchorFrame)
      : frames.length - 1
    this.showFrame(this.frameIndex)

    if (previousLayers) {
      previousLayers.forEach((layer) => {
        if (this.map && this.map.hasLayer(layer)) this.map.removeLayer(layer)
      })
    }

    if (preserve) {
      if (this.playing && !this.zooming) this.startTimer()
      return
    }

    // Hold on the newest frame while its tiles load, then warm the rest of the loop.
    await this.waitForLayerLoad(this.tileLayers[this.frameIndex])
    if (generation !== this.syncGeneration || !this.map) return

    await this.warmOfflineFrames(this.frameIndex, generation)
    if (generation !== this.syncGeneration || !this.map) return

    // Animate oldest → newest once frames are cached.
    this.frameIndex = 0
    this.showFrame(this.frameIndex)
    if (this.playing && !this.zooming) this.startTimer()
  }

  flushPendingQuietRefresh() {
    const pending = this.pendingQuietRefresh
    if (!pending) return
    this.pendingQuietRefresh = null
    if (pending.generation !== this.syncGeneration || !this.map) return
    if (this.resolveMode() !== "librewxr" || this.selectedSiteId) return

    void this.commitFrameSet({
      frames: pending.frames,
      mode: pending.mode,
      product: pending.product,
      compositeLayer: pending.compositeLayer,
      previousLayers: pending.previousLayers,
      preserve: true,
      generation: pending.generation,
    })
  }

  waitForLayerLoad(layer, timeoutMs = 8000) {
    if (!layer || !this.map) return Promise.resolve()

    // Level III image overlays are already decoded blobs — no wait needed.
    if (typeof layer.setUrl === "function" && layer._url?.startsWith?.("blob:")) {
      return Promise.resolve()
    }

    if (typeof layer.isLoading === "function" && !layer.isLoading()) {
      return Promise.resolve()
    }

    return new Promise((resolve) => {
      let settled = false
      const done = () => {
        if (settled) return
        settled = true
        layer.off?.("load", done)
        window.clearTimeout(timer)
        resolve()
      }
      const timer = window.setTimeout(done, timeoutMs)
      layer.once?.("load", done)
      // If Leaflet already finished between the isLoading check and once().
      if (typeof layer.isLoading === "function" && !layer.isLoading()) done()
    })
  }

  /**
   * Prefetch inactive frames at opacity 0 while keeping the frozen frame visible.
   * After warming, leave only the frozen frame mounted (mount-only-active modes)
   * so drag/zoom stays cheap until animation starts.
   */
  async warmOfflineFrames(keepIndex, generation, concurrency = 2) {
    if (!this.map || this.tileLayers.length < 2) return

    const indices = this.tileLayers
      .map((_, index) => index)
      .filter((index) => index !== keepIndex)
    const detachAfterWarm = this.mountOnlyActiveFrame()

    let cursor = 0
    const workers = Array.from({ length: Math.min(concurrency, indices.length) }, async () => {
      while (cursor < indices.length) {
        if (generation !== this.syncGeneration || !this.map) return
        const index = indices[cursor]
        cursor += 1
        const layer = this.tileLayers[index]
        if (!layer) continue

        layer.setOpacity(0)
        if (!this.map.hasLayer(layer)) layer.addTo(this.map)
        await this.waitForLayerLoad(layer, 5000)
        if (generation !== this.syncGeneration || !this.map) return
        if (detachAfterWarm && this.map.hasLayer(layer)) {
          this.map.removeLayer(layer)
        }
      }
    })

    await Promise.all(workers)
  }

  setTimestamp(text, { nowcast = false } = {}) {
    if (!this.hasTimestampTarget) return
    this.timestampTarget.textContent = text
    this.timestampTarget.classList.toggle("is-nowcast", nowcast)
  }

  level3CacheKey(sector, product) {
    return `${sector}:${product}`
  }

  // Single-site tilts use Unidata Level III.
  // Results are cached per sector+product so site/tilt switches reuse downloads
  // (including empty lists when S3 listed no keys). All-load failures throw
  // from buildLevel3Frames so the catch below drops the entry and syncMode
  // can retry later instead of caching a poisoned [].
  async loadRidgeFrames(site, product = this.ridgeProduct()) {
    const key = this.level3CacheKey(site.sector, product)
    const cached = this.level3Cache.get(key)
    if (Array.isArray(cached?.frames)) return cached.frames
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

  async fetchLibreWxrMetadata({ force = false } = {}) {
    const now = Date.now()
    if (
      !force &&
      this.librewxrCache &&
      now - this.librewxrCacheAt < LIBREWXR_METADATA_TTL_MS
    ) {
      return this.librewxrCache
    }

    // Share one in-flight request so concurrent callers cannot overwrite the
    // cache out of order (last-write-wins by completion time).
    if (this.librewxrFetchPromise) return this.librewxrFetchPromise

    this.librewxrFetchPromise = this.loadLibreWxrMetadataJson().finally(() => {
      this.librewxrFetchPromise = null
    })
    return this.librewxrFetchPromise
  }

  async loadLibreWxrMetadataJson() {
    const response = await fetch(librewxrMetadataUrl(this.librewxrHostValue))
    if (!response.ok) throw new Error(`LibreWXR HTTP ${response.status}`)
    const json = await response.json()
    this.librewxrCache = json
    this.librewxrCacheAt = Date.now()
    return json
  }

  async loadLibreWxrFrames() {
    const api = await this.fetchLibreWxrMetadata()
    const tileHost = this.librewxrHostValue
    if (this.compositeLayer === "cloud") {
      return buildLibreWxrSatelliteFrames(api, { tileHost })
    }

    return buildLibreWxrRadarFrames(api, {
      tileHost,
      options: this.snowColorsEnabled ? LIBREWXR_OPTIONS_SNOW : LIBREWXR_OPTIONS_NOSNOW,
      includeNowcast: true,
    })
  }

  startMetadataRefresh() {
    this.stopMetadataRefresh()
    this.metadataTimer = window.setInterval(() => {
      if (!this.map || this.selectedSiteId || this.librewxrRefreshPromise) return
      void this.refreshLibreWxrFrames()
    }, LIBREWXR_METADATA_TTL_MS)
  }

  stopMetadataRefresh() {
    if (this.metadataTimer) {
      window.clearInterval(this.metadataTimer)
      this.metadataTimer = null
    }
  }

  async refreshLibreWxrFrames() {
    if (this.resolveMode() !== "librewxr") return
    if (this.librewxrRefreshPromise) return this.librewxrRefreshPromise

    this.librewxrRefreshPromise = this.runLibreWxrRefresh().finally(() => {
      this.librewxrRefreshPromise = null
    })
    return this.librewxrRefreshPromise
  }

  async runLibreWxrRefresh() {
    try {
      await this.fetchLibreWxrMetadata({ force: true })
      // User may have switched to a single-site tilt while metadata was in flight.
      // Do not force syncMode in ridge mode — that tears down Level III playback.
      if (!this.map || this.resolveMode() !== "librewxr" || this.selectedSiteId) return
      await this.syncMode({ force: true, preserveFrame: true })
    } catch (error) {
      console.warn("LibreWXR metadata refresh failed", error)
    }
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
      maxZoom: this.mapMaxZoom,
      // Only the active frame is mounted; keep the tile buffer tiny for drag/zoom.
      keepBuffer: 0,
      updateWhenIdle: true,
      updateWhenZooming: false,
      maxNativeZoom: LIBREWXR_MAX_NATIVE_ZOOM,
      className: "radar-tile-layer",
      attribution: LIBREWXR_ATTR,
    }

    return L.tileLayer(frame.urlTemplate, common)
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
    if (!this.frames.length || !this.map) return
    const nextIndex = ((index % this.frames.length) + this.frames.length) % this.frames.length
    const nextLayer = this.tileLayers[nextIndex]
    const prevLayer = this.tileLayers[this.frameIndex]

    // Mount only the active frame. Keeping every LibreWXR tile layer at
    // opacity 0 still fetches/paints tiles and makes drag/zoom feel stuck.
    // Level III desktop can opacity-toggle decoded image overlays cheaply.
    if (this.mountOnlyActiveFrame()) {
      if (nextLayer) {
        if (!this.map.hasLayer(nextLayer)) nextLayer.addTo(this.map)
        nextLayer.setOpacity(0.7)
      }
      if (prevLayer && prevLayer !== nextLayer && this.map.hasLayer(prevLayer)) {
        this.map.removeLayer(prevLayer)
      }
    } else {
      this.tileLayers.forEach((layer, i) => {
        if (!this.map.hasLayer(layer)) layer.addTo(this.map)
        layer.setOpacity(i === nextIndex ? 0.7 : 0)
      })
    }

    this.frameIndex = nextIndex

    const frame = this.frames[this.frameIndex]
    if (frame) {
      this.setTimestamp(frame.label, { nowcast: Boolean(frame.isNowcast) })
    }
  }

  mountOnlyActiveFrame() {
    if (this.activeMode === "librewxr") return true
    return this.limitMemory && this.activeMode === "ridge"
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
        this.updateLayerUi()
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
    this.updateLayerUi()
    this.updateOptionUi()
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

  updateLayerUi() {
    const compositeActive = !this.selectedSiteId
    if (this.hasLayerControlsTarget) {
      this.layerControlsTarget.classList.toggle("hidden", !compositeActive)
    }

    if (this.hasLayerChipTarget) {
      this.layerChipTargets.forEach((chip) => {
        const active = compositeActive && chip.dataset.layer === this.compositeLayer
        chip.classList.toggle("is-active", active)
        chip.setAttribute("aria-pressed", active ? "true" : "false")
        chip.disabled = !compositeActive
      })
    }
  }

  updateOptionUi() {
    const precipComposite = !this.selectedSiteId && this.compositeLayer === "precip"

    if (this.hasOptionChipTarget) {
      this.optionChipTargets.forEach((chip) => {
        const option = chip.dataset.option
        const enabled = precipComposite && option === "snow"
        const active = enabled && this.snowColorsEnabled

        chip.classList.toggle("is-active", active)
        chip.setAttribute("aria-pressed", active ? "true" : "false")
        chip.disabled = !enabled
        chip.classList.toggle("is-disabled", !enabled)
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
