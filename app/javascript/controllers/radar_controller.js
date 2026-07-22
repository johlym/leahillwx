import { Controller } from "@hotwired/stimulus"
import L from "leaflet"
import {
  LIBREWXR_DEFAULT_HOST,
  LIBREWXR_OPTIONS_SNOW,
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
  resolvePreservedFrameIndex,
  ridgeProductForTilt,
  tileUrlsForViewport,
  prefetchImages,
} from "./helpers/radar_layers"
import { boundsForRadar, buildLevel3Frames } from "./helpers/level3_frames"
import { shouldLimitRadarMemory } from "./helpers/level3_utils"

// Full-viewport radar map: LibreWXR composite precip (+ nowcast),
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
    this.frames = []
    this.tileLayers = []
    this.siteMarkers = new Map()
    this.timer = null
    this.metadataTimer = null
    this.activeMode = null
    this.activeProduct = null
    this.librewxrCache = null
    this.librewxrCacheAt = 0
    this.librewxrFetchPromise = null
    this.librewxrRefreshPromise = null
    this.pendingQuietRefresh = null
    this.zooming = false
    this.warmingFrames = false
    this.frameRevealToken = 0
    this.revealingFrame = false
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

    // Zoom 7 matches LibreWXR regional tiles around the station
    // (e.g. /v2/radar/.../256/7/21/43/...).
    this.map.setView([ this.latValue, this.lonValue ], 7)

    this.addSiteMarkers()

    this.onZoomStart = () => {
      // Avoid animating (add/remove layers) while the user is pinching.
      this.zooming = true
      this.stopTimer()
      this.cancelPendingFrameReveal()
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
    this.warmingFrames = false
    this.cancelPendingFrameReveal()
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
    // Level III single-site data loads on demand when a site (or non-default
    // tilt for a selected site) is chosen — not on initial composite load.
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
      // Drop any in-flight reveal so a paused UI cannot still swap frames.
      this.cancelPendingFrameReveal()
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
    return "librewxr"
  }

  ridgeProduct() {
    return ridgeProductForTilt(this.selectedTilt, RIDGE_PRODUCT)
  }

  async syncMode({ force = false, preserveFrame = false } = {}) {
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
        const message = mode === "ridge" ? `No frames for ${this.selectedTilt}°` : "No frames"
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
          previousLayers,
        }
        return
      }

      await this.commitFrameSet({
        frames,
        mode,
        product,
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
      this.frames = []
      this.clearRadarLayers()
      this.setTimestamp("Radar unavailable")
    }
  }

  /**
   * Apply a loaded frame set.
   * Initial loads: freeze on the newest frame until its tiles are ready, then
   * animate newest → older. Frame advances keep the previous layer up until the
   * next one has loaded so we never flash an empty radar pane.
   * Quiet refreshes: preserve playback index and resume after the new layer paints.
   */
  async commitFrameSet({
    frames,
    mode,
    product,
    previousLayers,
    preserve,
    generation = this.syncGeneration,
  }) {
    if (!this.map || !frames?.length) return

    this.stopTimer()
    // Invalidate any in-flight reveal; must clear revealingFrame or playback
    // stays stuck after a mode swap (and play/pause cannot recover).
    this.cancelPendingFrameReveal()
    this.warmingFrames = false
    // Capture before replacing this.frames (quiet refresh keeps old list until now).
    const anchorFrame = preserve ? this.frames[this.frameIndex] : null
    const nextLayers = frames.map((frame) => this.createFrameLayer(frame))
    this.activeMode = mode
    this.activeProduct = product
    this.frames = frames
    this.tileLayers = nextLayers
    this.frameIndex = preserve
      ? resolvePreservedFrameIndex(frames, anchorFrame)
      : frames.length - 1
    this.showFrame(this.frameIndex, { immediate: true })
    this.detachInactiveRadarLayers(this.frameIndex)

    // Wait for the mounted frame before tearing down the previous set so quiet
    // refreshes do not blink to the basemap.
    this.warmingFrames = true
    await this.waitForLayerLoad(this.tileLayers[this.frameIndex])
    if (generation !== this.syncGeneration || !this.map) {
      this.warmingFrames = false
      return
    }

    if (previousLayers) {
      previousLayers.forEach((layer) => {
        if (this.map && this.map.hasLayer(layer)) this.map.removeLayer(layer)
      })
    }

    this.warmingFrames = false
    if (this.playing && !this.zooming) this.startTimer()

    if (!preserve) {
      // Prefetch older frames ahead of the newest→older loop.
      void this.prefetchUpcomingFrames(this.frameIndex, generation, 2)
    }
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

      // Do not trust a synchronous !isLoading() right after addTo — Leaflet
      // reports idle before the first tile request is queued, which made us
      // tear down the previous frame onto an empty next layer (a visible blink).
      requestAnimationFrame(() => {
        if (settled) return
        const tileCount = layer._tiles ? Object.keys(layer._tiles).length : 0
        const loading = typeof layer.isLoading === "function" ? layer.isLoading() : true
        if (!loading && tileCount > 0) done()
      })
    })
  }

  /**
   * Prefetch a few upcoming frames off-map (HTTP cache only).
   * Kept small so we do not starve the active layer's tile requests.
   */
  async prefetchUpcomingFrames(fromIndex, generation, count = 2) {
    if (!this.map || this.frames.length < 2 || count < 1) return

    const urls = []
    for (let step = 1; step <= count; step += 1) {
      // Playback steps newest → older (index decreases).
      const index = (fromIndex - step + this.frames.length) % this.frames.length
      urls.push(...this.viewportUrlsForFrame(this.frames[index]))
    }

    await prefetchImages(urls, {
      concurrency: 4,
      timeoutMs: 2500,
      isCancelled: () => generation !== this.syncGeneration || !this.map,
    })
  }

  viewportUrlsForFrame(frame) {
    if (!frame || !this.map) return []

    // Level III frames are already decoded blob images — one URL covers the overlay.
    if (frame.kind === "level3" && frame.url) return [ frame.url ]
    if (!frame.urlTemplate) return []

    const bounds = this.map.getPixelBounds()
    if (!bounds) return []

    return tileUrlsForViewport(frame.urlTemplate, {
      zoom: Math.min(Math.round(this.map.getZoom()), this.mapMaxZoom),
      pixelMinX: bounds.min.x,
      pixelMinY: bounds.min.y,
      pixelMaxX: bounds.max.x,
      pixelMaxY: bounds.max.y,
      tileSize: 256,
      pad: 0,
    })
  }

  detachInactiveRadarLayers(keepIndex) {
    if (!this.map) return
    this.tileLayers.forEach((layer, index) => {
      if (!layer || index === keepIndex) return
      if (this.map.hasLayer(layer)) this.map.removeLayer(layer)
      if (typeof layer.setOpacity === "function") layer.setOpacity(0)
    })
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
    return buildLibreWxrRadarFrames(api, {
      tileHost: this.librewxrHostValue,
      options: LIBREWXR_OPTIONS_SNOW,
      includeNowcast: true,
    })
  }

  /** Cancel an in-flight frame reveal and allow advances again. */
  cancelPendingFrameReveal() {
    this.frameRevealToken += 1
    this.revealingFrame = false
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
      // Load as soon as the layer is mounted — updateWhenIdle delayed first paint
      // when frames are swapped every 500ms.
      updateWhenIdle: false,
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

  showFrame(index, { immediate = false } = {}) {
    if (!this.frames.length || !this.map) return
    const nextIndex = ((index % this.frames.length) + this.frames.length) % this.frames.length

    if (immediate || !this.mountOnlyActiveFrame()) {
      this.applyFrame(nextIndex, { waitForLoad: false })
      return
    }

    // Async reveal: keep the current frame visible until the next one loads.
    void this.revealFrame(nextIndex)
  }

  async revealFrame(nextIndex) {
    if (!this.map || !this.frames.length) return
    if (this.revealingFrame) return

    const token = ++this.frameRevealToken
    this.revealingFrame = true
    try {
      await this.applyFrame(nextIndex, { waitForLoad: true, token })
      if (token === this.frameRevealToken && this.map) {
        void this.prefetchUpcomingFrames(nextIndex, this.syncGeneration, 2)
      }
    } finally {
      if (token === this.frameRevealToken) this.revealingFrame = false
    }
  }

  async applyFrame(nextIndex, { waitForLoad = false, token = null } = {}) {
    if (!this.map || !this.frames.length) return

    const nextLayer = this.tileLayers[nextIndex]
    const prevIndex = this.frameIndex
    const prevLayer = this.tileLayers[prevIndex]
    const switching = nextIndex !== prevIndex && prevLayer && nextLayer && prevLayer !== nextLayer

    if (this.mountOnlyActiveFrame() || this.warmingFrames) {
      if (nextLayer) {
        // Load the next frame underneath the current one, then drop the cover.
        // That avoids a basemap blink between time slots.
        if (switching) {
          nextLayer.setOpacity(0.7)
          if (typeof nextLayer.setZIndex === "function") nextLayer.setZIndex(190)
          if (!this.map.hasLayer(nextLayer)) nextLayer.addTo(this.map)
          if (typeof prevLayer.setZIndex === "function") prevLayer.setZIndex(210)
          prevLayer.setOpacity(0.7)

          if (waitForLoad) {
            await this.waitForLayerLoad(nextLayer, 1500)
            if (token != null && token !== this.frameRevealToken) return
            if (!this.map) return
          }

          // One paint with both layers mounted (next under prev), then uncover.
          await new Promise((resolve) => requestAnimationFrame(resolve))
          if (token != null && token !== this.frameRevealToken) return
          if (!this.map) return

          if (typeof nextLayer.setZIndex === "function") nextLayer.setZIndex(200)
          if (this.map.hasLayer(prevLayer)) this.map.removeLayer(prevLayer)
          prevLayer.setOpacity(0)
          if (typeof prevLayer.setZIndex === "function") prevLayer.setZIndex(200)
        } else {
          if (!this.map.hasLayer(nextLayer)) nextLayer.addTo(this.map)
          nextLayer.setOpacity(0.7)
          if (typeof nextLayer.setZIndex === "function") nextLayer.setZIndex(200)
        }
      }
      this.detachInactiveRadarLayers(nextIndex)
    } else {
      // Desktop Level III: keep every decoded overlay mounted and opacity-toggle.
      this.tileLayers.forEach((layer, i) => {
        if (!this.map.hasLayer(layer)) layer.addTo(this.map)
        layer.setOpacity(i === nextIndex ? 0.7 : 0)
        if (typeof layer.setZIndex === "function") {
          layer.setZIndex(i === nextIndex ? 210 : 200)
        }
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
    if (this.warmingFrames || this.revealingFrame || this.zooming || !this.playing) return
    // Frames are oldest→newest; step backward so the loop plays newest → older.
    this.showFrame(this.frameIndex - 1)
  }

  startTimer() {
    this.stopTimer()
    if (!this.playing || this.warmingFrames || this.zooming || this.frames.length < 2) return
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
