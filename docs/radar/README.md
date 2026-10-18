# Radar page

The `/radar` route is a full-viewport live weather radar map for Lea Hill Weather.

## What you see

- Stock site header (with a **Radar** nav link)
- Full-bleed Leaflet map filling the remaining viewport
- Compact attribution footer (LibreWXR, NEXRAD/Unidata, OpenStreetMap, CARTO)
- No page scroll: the shell is locked to `100svh` / `100dvh`

## Data sources

| Mode | Source | When |
|---|---|---|
| **Composite precip** (default) | [LibreWXR](https://librewxr.net/) radar tiles (MRMS/NOAA + regional NWP / ECMWF fill) | No site selected |
| **Single site** | Unidata Level III reflectivity (`N0B` / `NAB` / `N1B` tilts) plotted client-side | User selects ATX / RTX / LGX |

Composite tiles come from `LIBREWXR_API_BASE` (default `https://api.librewxr.net`). The browser talks to LibreWXR directly (no Rails proxy).

### LibreWXR composite features

- **Nowcast:** `radar.nowcast` frames appended after past radar (up to ~60 minutes when available)
- **Snow colors:** always on (`smooth_snow = 1_1`, per-pixel rain/snow)
- **Regional NWP:** server-side in LibreWXR (HRRR over CONUS, etc.) — no client work beyond attribution
- **Color scheme:** LibreWXR scheme `6` (NEXRAD Level III) for composite tiles
- **Performance:** only the active radar frame is mounted. First load (and other user-facing composite loads) cache every frame’s viewport tiles before mounting radar, then paint the newest frame and play oldest → newest. Advances keep the previous frame up until the next one loads (no empty flashes; no opacity-0 layer stacking).
- **Load progress:** a bar above the playback controls stays visible for the whole user-facing load (initial composite, site, tilt) and hides once the requested frame set is ready to play. Site/tilt progress follows Level III frame downloads; composite progress follows viewport tile prefetch for every frame, then the first paint. Quiet metadata refreshes do not show it.

Weather alerts come from LibreWXR (NWS/WMO CAP near the station), merged with any
active OpenWeather alerts. The homepage shows a compact bar (indicator, title,
expiry) linking to `/alerts` for the full text. Alerts are not shown on `/radar`.

### Local NEXRAD sites

| ID | IEM sector | Name | Role |
|---|---|---|---|
| KATX | ATX | Camano Island | Primary Puget Sound coverage |
| KRTX | RTX | Portland | Southern approaches |
| KLGX | LGX | Langley Hill | Coastal / Pacific inbound |

Only **one** site is active at a time (never stacked). Selecting the active site again, or **Composite**, returns to LibreWXR.

Site markers on the map mirror the chip control: click a marker to toggle that overlay.

Single-site Level III uses a client-side NWS-style reflectivity palette (−30 → 75 dBZ; ND transparent). Snow blues on the composite come from LibreWXR (`smooth_snow`); Level III reflectivity products do not encode precip type.

## Animation

- **LibreWXR precip:** past frames from `/public/weather-maps.json`, plus nowcast when present. Metadata refreshes every ~3 minutes.
- **Single site:** Unidata Level III objects from `https://unidata-nexrad-level3.s3.amazonaws.com` (`{SECTOR}_{PRODUCT}_{YYYY}_{MM}_{DD}_{HH}_{MI}_{SS}`), decoded in-browser and drawn as Leaflet image overlays (**1800×1800** on desktop, **900×900** on coarse/narrow viewports). Tilt selector (site-only): `0.5°` → `N0B`, `1.0°` → `NAB` (~0.9°), `1.5°` → `N1B`. Level III data loads on demand when a site is selected (or when a non-default tilt is chosen for that site) — not on initial composite load.

Playback controls: play/pause + timestamp (Pacific time). Past frames are prefixed with `Past ·`; nowcast frames with `Future ·`. Default is autoplay once every frame’s viewport tiles are cached.

### Memory / zoom notes

- **Composite** (LibreWXR) keeps animation frames mounted and opacity-toggles between them so Leaflet does not re-fetch tiles every frame. `maxNativeZoom` is **12**.
- **Single-site Level III** on memory-limited clients mounts only the **active** image overlay (inactive frames are detached).
- Mobile / coarse-pointer clients cap `maxZoom` at **9** (desktop **11**), use smaller Level III canvases, and fewer frames.

## Default viewport

The map opens at **zoom 7** centered on `LOCATION_LAT` / `LOCATION_LON` (required env vars; see `env.sample`), matching LibreWXR regional radar tile scale.

## Mobile / small screens

- Viewport height uses `100svh` to avoid iOS Safari chrome causing page scroll.
- Mobile nav menu is absolutely positioned over the map (does not expand document height).
- Playback button and site chips use ≥44px touch targets on small screens.
- Site chip row scrolls horizontally when needed.
- Radar site markers use large tappable hit areas.
- Zoom/memory caps above apply automatically via `shouldLimitRadarMemory()` (coarse pointer, narrow viewport, or `navigator.deviceMemory ≤ 4`).

## Code map

| Piece | Path |
|---|---|
| Route | `config/routes.rb` → `radar#index` |
| Controller | `app/controllers/radar_controller.rb` |
| Site metadata | `app/models/radar_site.rb` |
| View | `app/views/radar/index.html.erb` |
| Slim footer | `app/views/layouts/shared/_footer_radar.html.erb` |
| CSS | `app/assets/stylesheets/components/radar.css` |
| Stimulus controller | `app/javascript/controllers/radar_controller.js` |
| Frame helpers | `app/javascript/controllers/helpers/radar_layers.js` |

Leaflet JS comes from the `leaflet` npm package (bundled by esbuild). MapLibre GL (`maplibre-gl` + `@maplibre/maplibre-gl-leaflet`) powers the CARTO vector basemap under Leaflet. Leaflet / MapLibre CSS are vendored at `app/assets/stylesheets/vendor/`.

### Basemap notes

- Primary basemap: **CARTO Dark Matter vector** via MapLibre GL (`dark-matter-gl-style`), mounted under Leaflet with `@maplibre/maplibre-gl-leaflet` so radar overlays stay Leaflet tile/image layers.
- Set `CARTO_API_KEY` (free from [carto.com/basemaps/apikey](https://carto.com/basemaps/apikey/)) so the style URL includes `?key=…`. Vector is not watermarked today without a key, but CARTO recommends attaching one (and may require it later). The key is passed into the page as a Stimulus value (client-side by design; bind it to your site domain when requesting).
- If the vector basemap errors repeatedly (or MapLibre fails to init), the controller falls back once to Esri World Dark Gray raster tiles.
- Leaflet’s default `mix-blend-mode: plus-lighter` on raster tiles is overridden on this page; the MapLibre canvas basemap does not use that blend mode.

## Local development

```bash
# Env
cp env.sample .env   # set LOCATION_LAT / LOCATION_LON / CARTO_API_KEY
# optional: LIBREWXR_API_BASE=https://api.librewxr.net

# Assets
yarn build
yarn build:css

# App
bin/rails server
# open http://localhost:3000/radar
```

External LibreWXR / Unidata hosts must be reachable from the browser (no server-side proxy).

## Tests

```bash
yarn test:js
bin/rails test test/models/radar_site_test.rb test/controllers/radar_controller_test.rb
bin/rails test:system TEST=test/system/radar_smoke_test.rb
```

CI runs `yarn test:js` in the unit-test job and `yarn build` / `yarn build:css` before system tests (see `.github/workflows/ci.yml`).

## Attribution

Required attributions are shown in the slim footer and Leaflet attribution control:

- Radar © [LibreWXR](https://librewxr.net/) (MRMS/NOAA, HRRR/NWP)
- Single-site NEXRAD / [Unidata](https://registry.opendata.aws/noaa-nexrad/)
- Map © [OpenStreetMap](https://www.openstreetmap.org/copyright) © [CARTO](https://carto.com/attributions)
