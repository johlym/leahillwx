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
  buildMosaicFrames,
  buildRidgeFrames,
  buildRainviewerFrames,
  boundsForRadius,
  ridgeListUrl,
} from "./helpers/radar_layers"

// Full-viewport radar map: IEM mosaic (default), optional single-site RIDGE
// (KATX/KRTX/KLGX), RainViewer at low zoom when no site is selected.
export default class extends Controller {
  static targets = [
    "map",
    "controls",
    "playPause",
    "playIcon",
    "pauseIcon",
    "timestamp",
    "siteChip",
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
    this.frames = []
    this.tileLayers = []
    this.siteMarkers = new Map()
    this.timer = null
    this.activeMode = null
    this.rainviewerCache = null
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
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
      this.resizeObserver = null
    }
    if (this.map) {
      this.map.off("zoomend", this.onZoom)
      this.map.remove()
      this.map = null
    }
    this.tileLayers = []
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

  // --- Mode / frames --------------------------------------------------------

  resolveMode() {
    if (this.selectedSiteId) return "ridge"
    if (this.map && this.map.getZoom() <= this.wideZoomMaxValue) return "rainviewer"
    return "mosaic"
  }

  async syncMode({ force = false } = {}) {
    const mode = this.resolveMode()
    if (!force && mode === this.activeMode && this.frames.length > 0) return

    const generation = ++this.syncGeneration
    this.stopTimer()
    this.clearRadarLayers()
    this.frames = []

    try {
      let frames
      if (mode === "ridge") {
        const site = this.sitesValue.find((s) => s.id === this.selectedSiteId)
        if (!site) {
          this.selectedSiteId = null
          this.updateSiteUi()
          return this.syncMode({ force: true })
        }
        frames = await this.loadRidgeFrames(site.sector)
      } else if (mode === "rainviewer") {
        frames = await this.loadRainviewerFrames()
      } else {
        frames = buildMosaicFrames()
      }

      if (generation !== this.syncGeneration || !this.map) return

      if (frames.length === 0) {
        this.activeMode = null
        if (this.hasTimestampTarget) this.timestampTarget.textContent = "No frames"
        return
      }

      this.activeMode = mode
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
      this.frames = []
      this.tileLayers = []
      if (this.hasTimestampTarget) {
        this.timestampTarget.textContent = "Radar unavailable"
      }
    }
  }

  async loadRidgeFrames(sector) {
    const end = new Date()
    const start = new Date(end.getTime() - 90 * 60_000)
    const response = await fetch(ridgeListUrl(sector, start, end))
    if (!response.ok) throw new Error(`IEM ridge list HTTP ${response.status}`)
    const data = await response.json()
    const scans = data.scans || []
    return buildRidgeFrames(sector, scans)
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
