# lhwx.org

Rails 8.1 app for [lhwx.org](https://lhwx.org): a live personal weather-station dashboard (home, reports, graphs, records, trends, almanac, radar). Station readings arrive through an authenticated measurement API (normally from an external Rust `wxlistener`, **not** in this repo). Sidekiq pulls forecast, AQI, alerts, and other third-party cards.

Visual language: [`DESIGN.md`](DESIGN.md). Radar ops: [`docs/radar/README.md`](docs/radar/README.md). Cursor Cloud caveats: [`AGENTS.md`](AGENTS.md).

## Stack

| Layer | Version / notes |
| ----- | --------------- |
| Ruby | 4.0.1 (`.ruby-version`) |
| Rails | 8.1 |
| Node | 24.x |
| DB / jobs | PostgreSQL, Redis, Sidekiq + sidekiq-cron (`config/schedule.yml`) |
| Frontend | Tailwind CSS 4, esbuild, Stimulus, Turbo, Leaflet, MapLibre GL, Chart.js |
| Timezone | `America/Los_Angeles` |

## Local setup

```bash
cp env.sample .env
# set MEASUREMENT_API_KEY, LOCATION_LAT, LOCATION_LON, OPENWEATHER_API_KEY
bundle install
yarn install
bin/rails db:prepare
yarn build && yarn build:css    # app/assets/builds is gitignored
bin/rails server                # Puma :3000
# in another terminal, if you need jobs:
bundle exec sidekiq
```

`bin/dev` / `Procfile.dev` also starts `listener:` → `../listener/target/release/wxlistener`. That binary is **not** in this repo and will fail. Prefer `bin/rails server` + Sidekiq unless you have the collector locally.

Interactive OpenAPI for the ingest API is at `/docs`.

## Ingest API

The homepage renders an offline empty state when `weather_measurements` is empty. Post at least one reading to populate live conditions.

Auth: `Authorization: Bearer <MEASUREMENT_API_KEY>`. Blank or wrong key → **401**.

| Method | Path | Success |
| ------ | ---- | ------- |
| `POST` | `/api/v1/weather_measurement` | **204** (empty body) |
| `POST` | `/api/v1/weather_measurement/bulk` | **202** `{ "accepted": N, "status": "processing" }` |

Single create is idempotent on `reading_date_time` (duplicate → 204). Bulk max is **1000** rows; the write runs in `BulkWriteMeasurementsJob`. Bulk flags (string `"true"` only): `update_records`, `overwrite`.

Required scalar fields (model validations): `reading_date_time`, `barometer_abs`, `barometer_rel`, `gust_speed`, `light`, `humidity`, `temperature`, `rain_day`, `rain_rate`, `uv`, `uvi`, `wind_dir`, `wind_speed`.

Units on the wire: temperature **°C**, barometer **hPa**, wind **m/s**, rain **mm**. The UI converts to °F / inHg / mph / inches.

`heat_index`, `dew_point`, and `wind_chill` are **not** accepted on ingest (those columns were dropped). Dew point and feels-like are computed on the model from temperature, humidity, and wind.

```bash
curl -X POST http://localhost:3000/api/v1/weather_measurement \
  -H "Authorization: Bearer $MEASUREMENT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "weather_measurement": {
      "reading_date_time": "2026-08-20T21:00:00Z",
      "barometer_abs": 1013.2,
      "barometer_rel": 1015.0,
      "gust_speed": 2.5,
      "light": 1200.0,
      "humidity": 65,
      "temperature": 18.5,
      "rain_day": 0.0,
      "rain_rate": 0.0,
      "uv": 3,
      "uvi": 3.0,
      "wind_dir": 180,
      "wind_speed": 1.2
    }
  }'
```

Optional nested arrays: `soil[]`, `temp_probes[]`, and `temp_humidity[]` (channels 1–8 each). Duplicate channels are rejected. `temp_humidity` requires numeric `temperature` + `humidity` (optional boolean `battery_low`). `temp_probes` require `temperature`. `soil` requires moisture and/or temperature. Friendly names and merged Auxiliary Sensors rows live in `config/soil_channels.yml` (restart after edits; Action Cable still broadcasts the merge as `soil`). OpenAPI at `/docs` can lag the model — trust `weather_measurement.rb`.

**Bulk vs single:** only `POST /api/v1/weather_measurement` returns **422** `{ errors: [...] }` for validation. Bulk always **202** once enqueued; invalid rows are logged and skipped. Sidekiq retries the job up to 3 times on hard failures. `overwrite=true` wins over `update_records` (delete + insert). Default mode skips duplicate `reading_date_time` rows. Bulk uses `insert_all!` and does **not** fire Action Cable — use single create for live dashboard pushes.

**Rate limits** (Rack::Attack): 120 req/min per IP on `/api/`, 60/min on measurement POSTs → **429** JSON. Wrong or wrong-length `MEASUREMENT_API_KEY` → **401** (digest compare; never 500).

## Data sources

| Card / feature | Source | Job / trigger |
| -------------- | ------ | ------------- |
| Station observations | Measurement API | live insert + Action Cable broadcast |
| **AQI / PM2.5** | **AirNow** HourlyAQObs CSV (`AIRNOW_AQSID`, default Auburn 29th St `840530330047`) | `DownloadAirNowAqiJob` hourly at `:15`; also from `/` if latest is missing, stale (>8h), or not `source: airnow` |
| Forecast | OpenWeather One Call 3.0 | `DownloadOpenWeatherForecastJob` every 10 minutes (and from `/` if older than 1h, via `JobEnqueue.once` 10 min cooldown) |
| Sky/hazard cards | wildfire / aurora / ISS / planet-night jobs | Also from `/` via `JobEnqueue.once` (Redis NX cooldown 10–60 min) when snapshots are missing or stale |
| Alerts bar | LibreWXR + OpenWeather alerts from the forecast | async Turbo Frame `GET /alerts/bar` (needs `LOCATION_LAT` / `LOCATION_LON`) |
| Wildfire | `NearestWildfireResolver` | `DownloadNearestWildfireJob` every 30 min |
| Radar (`/radar`) | LibreWXR composite + Unidata Level III | browser-direct; see `docs/radar/README.md` |
| Earthquakes | USGS | `DownloadLatestEarthquakeJob` every minute |
| Aurora / ISS / planet night | NOAA / Celestrak / almanac | see `config/schedule.yml` |
| Webcams | static Auburn traffic + WSDOT airport URLs | client `image-refresh` every 60s |

### AQI rules (`Aqi`)

- `Aqi.latest` prefers `source: airnow`, then any row (legacy OpenWeather).
- `upsert_reading!` **never overwrites an AirNow hour with OpenWeather**. AirNow can replace OpenWeather for the same UTC hour.
- No job still writes `source: openweather` AQI. OpenWeather remains forecast + alert text only.
- Historical backfill: `rake aqi:backfill[start,end]` → `BackfillAirNowPm25Job`.
- Homepage sparkline buckets AirNow only.

## Environment (`env.sample`)

| Variable | What breaks without it |
| -------- | ---------------------- |
| `MEASUREMENT_API_KEY` | Ingest returns **401** when blank or wrong; homepage still renders the offline empty state without measurements |
| `LOCATION_LAT` / `LOCATION_LON` | Radar (`ENV.fetch`), wildfire, LibreWXR alerts, several geo jobs |
| `LOCATION_ELEVATION_FT` | Optional; defaults to 416. Reduces station pressure to sea-level / altimeter |
| `OPENWEATHER_API_KEY` | Forecast download |
| `AIRNOW_AQSID` | Optional; defaults to Auburn 29th St |
| `LIBREWXR_API_BASE` | Optional; defaults to `https://api.librewxr.net` |
| `CARTO_API_KEY` | Optional but recommended; `/radar` CARTO vector Dark Matter style URL |
| `SENTRY_DSN` | Optional; error reporting only (tracing and profiling disabled) |
| `SEND_WX` | Must be exactly `true` to upload to WU / PWS / AWEKAS / WeatherCloud / CWOP |
| `SIDEKIQ_USER` / `SIDEKIQ_PASSWORD` | Production `/sidekiq` (open in development) |
| `MEASUREMENT_RETENTION_DAYS` | Optional; default `1095`. Nightly purge of raw `weather_measurements` older than this |

## Growth

Reports (`reports` / `report_entries`) and records (`records`) are the long-term store for daily/hourly extremes and all-time highs. Raw `weather_measurements` are kept for the live dashboard, re-aggregation, and a rolling history window.

`PurgeOldWeatherMeasurementsJob` (08:15 UTC daily) deletes raw rows older than `MEASUREMENT_RETENTION_DAYS` (default 3 years) in batches, then rebuilds the Redis vanity counter. `RecalculateMeasurementTotalCountJob` (08:10 UTC) repairs `WeatherMeasurements::TotalCount` if increments drift. The counter uses Redis `SET NX` so a repair does not clobber a concurrent increment.

## Live status (LIVE / STALE / OFFLINE)

The header badge reflects **Action Cable connectivity**, not reading age:

| Badge | Meaning |
| ----- | ------- |
| **LIVE** | Turbo Cable stream to `weather_measurements` is open |
| **STALE** | Stream down, but a last-reading timestamp exists on the page |
| **OFFLINE** | No measurements in the database yet |

A reading from yesterday still shows **STALE** (not OFFLINE) if the page rendered with a measurement. There is no “stale after N minutes” threshold on the header. The AQI card separately marks `observed_at` older than **8 hours** as stale and can trigger an AirNow refresh from `/`.

## Records timezone

Yearly records and date-bucketed extremes use **America/Los_Angeles** calendar bounds (`Records::MeasurementScope.pacific_year_bounds`), not UTC. A reading at 2025-12-31 16:00 Pacific (2026-01-01 00:00 UTC) counts in **2025**. The current calendar year excludes today’s readings (scope ends at start of today Pacific). Past years use full Dec 31.

## Lint / test

```bash
bin/rubocop
bin/rails test
bin/rails test:system
bin/brakeman
bin/bundler-audit
bin/database_consistency
```

GitHub `scan_ruby` fails the job on Brakeman or bundler-audit findings. `config/brakeman.ignore` documents three static QFF `Arel.sql` fragments in `LiveCardHourlyRanges` (station elevation, not request input).

## Pitfalls

- **Empty measurements table → offline homepage, not an error.** `/` returns 200 with a “Station offline / Awaiting first reading” card and an OFFLINE header badge. Forecast, cameras, and earthquakes still load. Seed via the ingest API.
- **`Procfile.dev` listener** points at a binary that is not in this repo.
- **Assets are gitignored.** Build (`yarn build` / `yarn build:css`) before serving.
- Forecast cron and `Forecast` comments both say every **10** minutes (`*/10`). Homepage refresh only enqueues if the latest forecast is older than 1 hour (debounced).
- Production CSP is **report-only** (`config/initializers/content_security_policy.rb`) — not yet enforcing.
