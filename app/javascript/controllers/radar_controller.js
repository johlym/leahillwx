import { Controller } from "@hotwired/stimulus"
import L from "leaflet"
import {
  LIBREWXR_DEFAULT_HOST,
  LIBREWXR_OPTIONS_SNOW,
  LIBREWXR_OPTIONS_NOSNOW,
  LIBREWXR_MAX_NATIVE_ZOOM,
  LIBREWXR_METADATA_TTL_MS,
  LIBREWXR_ALERTS_TTL_MS,
  LIBREWXR_ATTR,
  CARTO_DARK_URL,
  CARTO_ATTR,
  ESRI_DARK_URL,
  ESRI_ATTR,
  RIDGE_PRODUCT,
  RIDGE_TILTS,
  normalizeLibreWxrHost,
  librewxrMetadataUrl,
  librewxrAlertsUrl,
  buildLibreWxrRadarFrames,
  buildLibreWxrSatelliteFrames,
  resolvePreservedFrameIndex,
  boundsForRadius,
  ridgeProductForTilt,
  alertPathStyle,
  alertPopupHtml,
} from "./helpers/radar_layers"
import { boundsForRadar, buildLevel3Frames } from "./helpers/level3_frames"
import { shouldLimitRadarMemory } from "./helpers/level3_utils"

// Full-viewport radar map: LibreWXR composite (precip / cloud / nowcast),
// single-site Unidata Level III tilts (KATX/KRTX/KLGX), alerts overlay.
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
    "alertBanner",
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
    this.arrowsEnabled = true
    this.snowColorsEnabled = true
    this.alertsEnabled = true
    this.frames = []
    this.tileLayers = []
    this.siteMarkers = new Map()
    this.timer = null
    this.metadataTimer = null
    this.alertsTimer = null
    this.activeMode = null
    this.activeProduct = null
    this.activeCompositeLayer = null
    this.librewxrCache = null
    this.librewxrCacheAt = 0
    this.alertsLayer = null
    this.alertPointMarkers = []
    this.alertsGeneration = 0
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
    })

    this.addBasemap()

    this.map.fitBounds(boundsForRadius(this.latValue, this.lonValue, 200), {
      padding: [12, 12],
      maxZoom: Math.min(8, this.mapMaxZoom),
    })

    this.addSiteMarkers()

    this.onZoomStart = () => {
      // Avoid animating (add/remove layers) while the user is pinching.
      this.stopTimer()
    }
    this.onZoomEnd = () => {
      if (this.playing) this.startTimer()
    }
    this.map.on("zoomstart", this.onZoomStart)
    this.map.on("zoomend", this.onZoomEnd)

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
    this.alertsGeneration += 1
    this.stopTimer()
    this.stopMetadataRefresh()
    this.stopAlertsRefresh()
    this.clearRadarLayers()
    this.clearAlertsOverlay()
    this.disposeLevel3Cache()
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
    if (this.map) {
      this.map.off("zoomstart", this.onZoomStart)
      this.map.off("zoomend", this.onZoomEnd)
      this.map.remove()
      this.map = null
    }
    this.siteMarkers.clear()
  }

  addBasemap() {
    this.basemap = L.tileLayer(CARTO_DARK_URL, {
      attribution: CARTO_ATTR,
      maxZoom: this.mapMaxZoom,
      keepBuffer: this.limitMemory ? 1 : 2,
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
          keepBuffer: this.limitMemory ? 1 : 2,
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
    this.syncAlerts()
    this.startAlertsRefresh()
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
    if (!option) return

    if (option === "arrows") {
      if (this.selectedSiteId || this.compositeLayer !== "precip") return
      this.arrowsEnabled = !this.arrowsEnabled
    } else if (option === "snow") {
      if (this.selectedSiteId || this.compositeLayer !== "precip") return
      this.snowColorsEnabled = !this.snowColorsEnabled
    } else if (option === "alerts") {
      this.alertsEnabled = !this.alertsEnabled
      this.updateOptionUi()
      if (this.alertsEnabled) {
        this.syncAlerts({ force: true })
      } else {
        // Invalidate in-flight fetches so a late response cannot re-render.
        this.alertsGeneration += 1
        this.clearAlertsOverlay()
        this.clearAlertBanner()
      }
      return
    } else {
      return
    }

    this.updateOptionUi()
    if (!this.selectedSiteId) this.syncMode({ force: true })
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

    const previousFrame =
      preserveFrame && this.frames.length > 0 ? this.frames[this.frameIndex] : null

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
    // Empty arrays are valid cache hits (no usable scans for this product).
    const cacheHit = Array.isArray(cachedFrames)

    // Quiet refresh: keep the current timestamp visible while new frames load.
    if (!cacheHit && !preserveFrame) {
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
        this.activeMode = null
        this.activeProduct = null
        this.activeCompositeLayer = null
        let message = "No frames"
        if (mode === "ridge") message = `No frames for ${this.selectedTilt}°`
        else if (this.compositeLayer === "cloud") message = "Cloud unavailable"
        this.setTimestamp(message)
        return
      }

      this.activeMode = mode
      this.activeProduct = product
      this.activeCompositeLayer = compositeLayer
      this.frames = frames
      this.frameIndex = resolvePreservedFrameIndex(frames, previousFrame)
      this.tileLayers = this.frames.map((frame) => this.createFrameLayer(frame))
      this.showFrame(this.frameIndex)

      if (this.playing) this.startTimer()
    } catch (error) {
      if (generation !== this.syncGeneration || !this.map) return
      console.error("Radar sync failed", error)
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

    const response = await fetch(librewxrMetadataUrl(this.librewxrHostValue))
    if (!response.ok) throw new Error(`LibreWXR HTTP ${response.status}`)
    this.librewxrCache = await response.json()
    this.librewxrCacheAt = now
    return this.librewxrCache
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
      arrows: this.arrowsEnabled ? "light" : null,
      includeNowcast: true,
    })
  }

  startMetadataRefresh() {
    this.stopMetadataRefresh()
    this.metadataTimer = window.setInterval(() => {
      if (!this.map || this.selectedSiteId) return
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
    try {
      await this.fetchLibreWxrMetadata({ force: true })
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
      // Opacity-0 layers used to stay mounted and still fetch tiles; keepBuffer
      // low so a stray mount cannot balloon RAM on mobile.
      keepBuffer: this.limitMemory ? 0 : 1,
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

    // Tile layers (LibreWXR): keep mounted and opacity-toggle.
    // Detaching each frame forces Leaflet to re-fetch tiles every 500ms and
    // flickers the composite loop. Level III on memory-limited clients still
    // mounts only the active imageOverlay — many 900–1800px canvases at once
    // OOMs mobile Safari when zoomed in.
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

  // --- Alerts ---------------------------------------------------------------

  startAlertsRefresh() {
    this.stopAlertsRefresh()
    this.alertsTimer = window.setInterval(() => {
      if (this.alertsEnabled) void this.syncAlerts({ force: true })
    }, LIBREWXR_ALERTS_TTL_MS)
  }

  stopAlertsRefresh() {
    if (this.alertsTimer) {
      window.clearInterval(this.alertsTimer)
      this.alertsTimer = null
    }
  }

  async syncAlerts({ force = false } = {}) {
    if (!this.alertsEnabled || !this.map) return
    if (!force && this.alertsFetchedAt && Date.now() - this.alertsFetchedAt < LIBREWXR_ALERTS_TTL_MS) {
      return
    }

    const generation = ++this.alertsGeneration
    try {
      const host = normalizeLibreWxrHost(this.librewxrHostValue)
      const response = await fetch(
        librewxrAlertsUrl(host, { lat: this.latValue, lon: this.lonValue }),
      )
      if (!response.ok) throw new Error(`LibreWXR alerts HTTP ${response.status}`)
      const collection = await response.json()
      // Drop stale responses when a newer fetch (or alerts-off) won the race.
      if (generation !== this.alertsGeneration || !this.alertsEnabled || !this.map) return
      this.alertsFetchedAt = Date.now()
      this.renderAlerts(collection)
    } catch (error) {
      if (generation !== this.alertsGeneration) return
      console.warn("LibreWXR alerts failed", error)
    }
  }

  renderAlerts(collection) {
    this.clearAlertsOverlay()
    if (!this.alertsEnabled || !this.map) return

    const features = Array.isArray(collection?.features) ? collection.features : []
    const withGeometry = features.filter((feature) => feature?.geometry)
    const withoutGeometry = features.filter((feature) => feature && !feature.geometry)

    if (withGeometry.length > 0) {
      this.alertsLayer = L.geoJSON(
        { type: "FeatureCollection", features: withGeometry },
        {
          style: (feature) => alertPathStyle(feature?.properties?.severity),
          onEachFeature: (feature, layer) => {
            layer.bindPopup(alertPopupHtml(feature.properties || {}), {
              maxWidth: 320,
              className: "radar-alert-popup",
            })
          },
        },
      ).addTo(this.map)
    }

    withoutGeometry.forEach((feature, index) => {
      const marker = L.circleMarker([this.latValue, this.lonValue], {
        radius: 8 + index,
        color: alertPathStyle(feature.properties?.severity).color,
        fillColor: alertPathStyle(feature.properties?.severity).fillColor,
        fillOpacity: 0.55,
        weight: 2,
        className: "radar-alert-point",
      })
        .addTo(this.map)
        .bindPopup(alertPopupHtml(feature.properties || {}), {
          maxWidth: 320,
          className: "radar-alert-popup",
        })
      this.alertPointMarkers.push(marker)
    })

    this.updateAlertBanner(features)
  }

  updateAlertBanner(features) {
    if (!this.hasAlertBannerTarget) return
    if (!this.alertsEnabled || features.length === 0) {
      this.clearAlertBanner()
      return
    }

    const titles = features
      .map((feature) => feature.properties?.title || feature.properties?.event)
      .filter(Boolean)
    const first = titles[0] || "Weather alert"
    const extra = titles.length > 1 ? ` (+${titles.length - 1} more)` : ""
    this.alertBannerTarget.textContent = `${first}${extra}`
    this.alertBannerTarget.classList.remove("hidden")
    this.alertBannerTarget.hidden = false
  }

  clearAlertBanner() {
    if (!this.hasAlertBannerTarget) return
    this.alertBannerTarget.textContent = ""
    this.alertBannerTarget.classList.add("hidden")
    this.alertBannerTarget.hidden = true
  }

  clearAlertsOverlay() {
    if (this.alertsLayer && this.map) {
      this.map.removeLayer(this.alertsLayer)
    }
    this.alertsLayer = null
    this.alertPointMarkers.forEach((marker) => {
      if (this.map && this.map.hasLayer(marker)) this.map.removeLayer(marker)
    })
    this.alertPointMarkers = []
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
        let active = false
        let enabled = true

        if (option === "arrows") {
          active = this.arrowsEnabled
          enabled = precipComposite
        } else if (option === "snow") {
          active = this.snowColorsEnabled
          enabled = precipComposite
        } else if (option === "alerts") {
          active = this.alertsEnabled
          enabled = true
        }

        chip.classList.toggle("is-active", active && enabled)
        chip.setAttribute("aria-pressed", active && enabled ? "true" : "false")
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
