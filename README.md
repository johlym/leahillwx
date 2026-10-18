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

Required scalar fields (model validations): `reading_date_time`, `barometer_abs`, `barometer_rel`, `gust_speed`, `light`, `humidity`, `temperature`, `rain_day`, `rain_rate`, `uvi`, `wind_dir`, `wind_speed`.

`uv` is optional. It is UV radiation in µW/m² (register 0x16). Leave it out when the gateway does not send that register. A missing value is stored as NULL, and averages and peaks ignore it rather than treating it as zero. `uvi` is the UV index and stays required. When a payload does include `uv`, that value is stored.

The records page shows highest solar irradiance in W/m². That number is the daily high `light` reading (lux) converted with `lux * 0.0079`.

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
      "uvi": 3.0,
      "wind_dir": 180,
      "wind_speed": 1.2
    }
  }'
```

Optional nested arrays (channels **1–8**, unique per array; extras → **422**):

| Array | Sensor | Required fields | Optional |
| ----- | ------ | --------------- | -------- |
| `soil[]` | WH51 moisture (and legacy soil temp) | `channel` plus `moisture` and/or `temperature` | `battery` (volts, ≥ 0). Battery-only rows are dropped. |
| `temp_probes[]` | WN34/WN34S probes | `channel`, `temperature` (°C) | `battery` (volts, ≥ 0). Battery-only rows are dropped. |
| `temp_humidity[]` | WH31/WN31 dip-switch | `channel`, `temperature` (°C), and `humidity` (%) | `battery_low` (boolean; `"true"`/`"1"`/`"t"` coerce) |

wxlistener maps WN31 livedata into `temp_humidity[]`. Indoor WH25 `intemp`/`inhumid` are **not** accepted on this API.

```json
"temp_humidity": [
  { "channel": 1, "temperature": 27.6, "humidity": 40, "battery_low": false }
]
```

### Auxiliary Sensors card

The homepage tile is **Auxiliary Sensors**. `WeatherMeasurement#soil_readings` merges `soil` + `temp_probes` + `temp_humidity` into one row per friendly name. Action Cable still ships that merge as `soil` (`data-weather-update-target="soil"`).

Display names live in `config/soil_channels.yml` (`SoilChannels`). Each key is one card row; map any of `soil:`, `temp_probe:`, `temp_humidity:` (channel 1–8). Channels that share a name collapse. Unnamed fallbacks: `Ch N`, `Temp Ch N`, `TH Ch N`. Legacy `Name: 1` channel-keyed YAML is rejected.

Temperature preference when merging: dedicated `temp_probes`, then `temp_humidity`, then legacy `soil.temperature`. The `%` column prefers soil `moisture`; otherwise it shows WN31 `humidity`. The YAML map is process-cached — restart Puma/Sidekiq after editing.

**Trust the model, not `/docs`.** `lib/assets/oas.json` still lists dropped `day_max_wind` / `rain_event` as required, omits `temp_humidity`, documents imperial units, and the bulk action annotation says 201. As-built wire units are °C / hPa / m/s / mm; bulk is **202**.

**Bulk vs single:** only `POST /api/v1/weather_measurement` returns **422** `{ errors: [...] }` for validation. Bulk always **202** once enqueued (payload >1000 rows is **422** before enqueue); invalid rows are logged and skipped. Sidekiq retries the job up to 3 times on hard failures. `overwrite=true` wins over `update_records` (delete + insert). Default mode skips duplicate `reading_date_time` rows. Bulk uses `insert_all!` and does **not** fire Action Cable — use single create for live dashboard pushes.

**Rate limits** (Rack::Attack): 120 req/min per IP on `/api/`, 60/min on measurement POSTs → **429** JSON. `/docs` is 30/min. A blank or wrong `MEASUREMENT_API_KEY` → **401** (SHA256 digest compare). Public celestial JSON (`GET /celestial/sun`, `GET /celestial/moon`) is 60/min and requires `year`/`month`/`day`.

## Data sources

| Card / feature | Source | Job / trigger |
| -------------- | ------ | ------------- |
| Station observations | Measurement API | live insert + Action Cable broadcast |
| **AQI / PM2.5** | **AirNow** HourlyAQObs CSV (`AIRNOW_AQSID`, default Auburn 29th St `840530330047`) | `DownloadAirNowAqiJob` hourly at `:15`; also from `/` if latest is missing, stale (>8h), or not `source: airnow` |
| Forecast | OpenWeather One Call 3.0 | `DownloadOpenWeatherForecastJob` every **10** minutes (`*/10`); homepage enqueues if latest is missing or older than 1h (`JobEnqueue.once`, 10 min cooldown) |
| Alerts bar | LibreWXR + OpenWeather alerts from the forecast | async Turbo Frame `GET /alerts/bar` (needs `LOCATION_LAT` / `LOCATION_LON`) |
| Wildfire | WA DNR + NIFC via `NearestWildfireResolver` | `DownloadNearestWildfireJob` every 30 min (homepage enqueues if the snapshot is missing or older than 30 min; cooldown 15 min) |
| Radar (`/radar`) | LibreWXR composite + Unidata Level III | browser-direct; see `docs/radar/README.md` |
| Earthquakes | USGS | `DownloadLatestEarthquakeJob` every minute (homepage reads `Earthquake.last(5)` only — no enqueue) |
| Aurora | NOAA SWPC | `DownloadAuroraOutlookJob` every 15 min (homepage enqueues if missing or older than 15 min; cooldown 10 min) |
| ISS | Celestrak TLE | `DownloadIssPassesJob` every 6 hours at `:15` (homepage enqueues if missing or older than 6h; cooldown 1 hour) |
| Planets Tonight | DE440s BSP (`Almanac::PlanetNightGenerator`) | `GeneratePlanetNightJob` daily 10:20 UTC; homepage enqueues if today’s row is missing (cooldown 30 min) |
| Webcams | static Auburn traffic + WSDOT airport URLs | client `image-refresh` every 60s |

### Sea-level pressure (`SeaLevelPressure`)

The console `barometer_rel` field is an uncalibrated offset (here it sits *below* station pressure) and is **not** used for display or uploads. Both reductions start from `barometer_abs` + `LOCATION_ELEVATION_FT` (default **416** ft).

| Helper | Formula | Used by |
| ------ | ------- | ------- |
| `sea_level_pressure` / `_inhg` | NWS ASOS altimeter (QNH) | CWOP, Weather Underground, PWSWeather, WeatherCloud |
| `sea_level_pressure_qff` | weewx/wview QFF (uses air temperature) | Homepage tile, reports, graphs, records, trends, AWEKAS |

`SeaLevelPressure.qff_sql` is the same QFF expression for Postgres aggregates (hourly live-card sparkline). At elevation `0` both helpers return station pressure unchanged. Third-party uploads stay gated by `SEND_WX=true`.

### Planets Tonight

Naked-eye planets only (Mercury–Saturn). A planet is on the card when its rise→set interval overlaps civil night **and** the rise is on the card’s calendar date (a predawn rise tomorrow belongs on tomorrow’s card). Rise/set times after local midnight render as `h:mm AM +1 day`.

`PlanetNight` is unique on `date`; homepage traffic upserts so concurrent jobs for the same night stay idempotent.

### Nearest wildfire

DNR “Current Fire Statistics” keeps rows until `CONTROL_DT` / `FIRE_OUT_DT` are set, including local-agency assists that never get those dates. `NearestWildfireResolver` treats a DNR row as live only if NIFC still lists the same name within **15 mi**, or it was discovered within **7 days**. Otherwise it falls back to the nearest NIFC fire in WA, then any NIFC fire. A successful “no live fire” poll writes an empty snapshot (`source: none`, `active: false`) so the card clears instead of sticking on last month’s incident.

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
| `LOCATION_ELEVATION_FT` | Optional; defaults to 416 ft (Leahill). QFF for the site UI + AWEKAS; QNH altimeter for CWOP / WU / PWS / WeatherCloud. Set `0` to leave station pressure unreduced. |
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

`PurgeOldWeatherMeasurementsJob` (08:15 UTC daily) deletes raw rows older than `MEASUREMENT_RETENTION_DAYS` (default 3 years) in batches, then rebuilds the Redis vanity counter. `RecalculateMeasurementTotalCountJob` (08:10 UTC) repairs `WeatherMeasurements::TotalCount` if increments drift. Increment and the homepage seed use Redis `SET NX` so filling a missing key does not clobber a concurrent increment. The nightly repair writes the count with a plain `SET`.

### Rain on reports (Pacific midnight counter)

`rain_day` on ingest is the station’s running total since **America/Los_Angeles midnight**, in **mm**. It can climb, reset, or drop (a correction). Daily and hourly `report_entries.rain` come from `WeatherData::RainTotal` (`DailyAggregator` / `HourlyAggregator`), not `max(rain_day)` and not `max − min`.

| Period | As-built total |
| ------ | -------------- |
| Daily | Last reading’s `rain_day` in that Pacific calendar day. Matches the homepage rain tile. |
| Hourly | Net counter deltas attributed to Pacific hour buckets. A spike that is later corrected is clawed back from the earlier hour. |
| Midnight carryover | Yesterday’s total still sitting on the first packets after midnight is **not** today’s rain until the counter resets or moves above that carryover. |

The daily aggregator rewrites that day’s hourly rain rows so they stay consistent with the full-day walk (`GenerateHourlyReportJob` hourly at `:01` UTC; `GenerateReportJob` daily at 08:01 UTC). Do not treat a mid-day peak as the official daily total.

## Live status (LIVE / STALE / OFFLINE)

The header badge reflects **Action Cable connectivity**, not reading age:

| Badge | Meaning |
| ----- | ------- |
| **LIVE** | Turbo Cable stream to `weather_measurements` is open |
| **STALE** | Stream down, but a last-reading timestamp exists on the page |
| **OFFLINE** | No measurements in the database yet |

A reading from yesterday still shows **STALE** (not OFFLINE) if the page rendered with a measurement. There is no “stale after N minutes” threshold on the header. The AQI card separately marks `observed_at` older than **8 hours** as stale and can trigger an AirNow refresh from `/`.

## Records timezone

Yearly record scans use **America/Los_Angeles** calendar bounds (`Records::MeasurementScope.pacific_year_bounds`), not the database session time zone. A reading at 2025-12-31 16:00 Pacific (2026-01-01 00:00 UTC) is inside the **2025** year. The current calendar year excludes today’s readings (scope ends at the start of today Pacific). Past years run through the end of Dec 31.

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
- **Do not plot `barometer_rel`.** Display and uploads reduce `barometer_abs`. Tests should set `LOCATION_ELEVATION_FT` (helper defaults to `0` so fixtures stay identity).
- Forecast cron and `Forecast` model comments both say every **10** minutes (`*/10`). Homepage still backfills if the latest row is older than **1 hour** (debounced 10 minutes).
- **`temp_humidity` is not indoor WH25.** Indoor gateway fields stay off the ingest API; WN31 channels belong in `temp_humidity[]`. Edit `config/soil_channels.yml` then restart to rename Auxiliary Sensors rows.
- Production CSP is **report-only** (`config/initializers/content_security_policy.rb`).
