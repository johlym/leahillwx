# Radar page

The `/radar` route is a full-viewport live weather radar map for Lea Hill Weather.

## What you see

- Stock site header (with a **Radar** nav link)
- Full-bleed Leaflet map filling the remaining viewport
- Compact attribution footer (IEM, RainViewer, OpenStreetMap, CARTO)
- No page scroll: the shell is locked to `100svh` / `100dvh`

## Data sources (keyless)

| Mode | Source | When |
|---|---|---|
| **Composite** (default) | Iowa Environmental Mesonet CONUS mosaic `nexrad-n0q` | Mid/high zoom, no site selected |
| **Single site** | IEM RIDGE tiles for one NEXRAD (`N0B` base reflectivity) | User selects ATX / RTX / LGX |
| **Wide** | [RainViewer](https://www.rainviewer.com/) Weather Maps API | Zoom ≤ 6 and no site selected |

### Local NEXRAD sites

| ID | IEM sector | Name | Role |
|---|---|---|---|
| KATX | ATX | Camano Island | Primary Puget Sound coverage |
| KRTX | RTX | Portland | Southern approaches |
| KLGX | LGX | Langley Hill | Coastal / Pacific inbound |

Only **one** RIDGE site is active at a time (never stacked). Selecting the active site again, or **Composite**, returns to the mosaic.

Site markers on the map mirror the chip control: click a marker to toggle that overlay.

> **Note:** IEM’s realtime single-site product for these radars is `N0B` (super-res base reflectivity). Older `N0Q` listings are empty for current scans.

## Animation

- **Mosaic:** ~55 minutes of history via `nexrad-n0q-m55m` … `m05m` plus current `nexrad-n0q` (5-minute steps).
- **RIDGE:** recent volume scans from `https://mesonet.agron.iastate.edu/json/radar.py?operation=list&…`, rendered as `ridge::{SECTOR}-N0B-{YYYYMMDDHHMI}` TMS layers.
- **RainViewer:** ~2 hours from `https://api.rainviewer.com/public/weather-maps.json`.

Playback controls: play/pause + timestamp (Pacific time). Default is autoplay.

## Default viewport

The map fits an approximate **200-mile radius** around `LOCATION_LAT` / `LOCATION_LON` (required env vars; see `env.sample`).

## Mobile / small screens

- Viewport height uses `100svh` to avoid iOS Safari chrome causing page scroll.
- Mobile nav menu is absolutely positioned over the map (does not expand document height).
- Playback button and site chips use ≥44px touch targets on small screens.
- Site chip row scrolls horizontally when needed.
- Radar site markers use large tappable hit areas.

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

Leaflet JS comes from the `leaflet` npm package (bundled by esbuild). Leaflet CSS is vendored at `app/assets/stylesheets/vendor/leaflet.css`.

### Basemap notes

- Primary basemap: CARTO Dark Matter via the **apex** host `basemaps.cartocdn.com` (letter subdomains like `a.basemaps.cartocdn.com` fail to resolve in some environments).
- If CARTO tiles error repeatedly, the controller falls back once to Esri World Dark Gray.
- Leaflet’s default `mix-blend-mode: plus-lighter` on tiles is overridden on this page so dark basemaps stay visible against the site palette.

## Local development

```bash
# Env
cp env.sample .env   # set LOCATION_LAT / LOCATION_LON

# Assets
yarn build
yarn build:css

# App
bin/rails server
# open http://localhost:3000/radar
```

External tile/JSON hosts must be reachable from the browser (no server-side proxy).

## Tests

```bash
yarn test:js
bin/rails test test/models/radar_site_test.rb test/controllers/radar_controller_test.rb
bin/rails test:system TEST=test/system/radar_smoke_test.rb
```

CI runs `yarn test:js` alongside the Rails test suite (see `.github/workflows/ci.yml`).

## Attribution

Required attributions are shown in the slim footer and Leaflet attribution control:

- Radar data © [Iowa Environmental Mesonet](https://mesonet.agron.iastate.edu/)
- Radar © [RainViewer](https://www.rainviewer.com/)
- Map © [OpenStreetMap](https://www.openstreetmap.org/copyright) © [CARTO](https://carto.com/attributions)
