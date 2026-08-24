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
| Frontend | Tailwind CSS 4, esbuild, Stimulus, Turbo, Leaflet, Chart.js |
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

The homepage **raises** if `weather_measurements` is empty (`Home::CurrentWeather::ConditionsComponent` reads `@current.temperature` with no nil guard). Post at least one reading before hitting `/`.

Auth: `Authorization: Bearer <MEASUREMENT_API_KEY>`. Blank or wrong key → **401**.

| Method | Path | Success |
| ------ | ---- | ------- |
| `POST` | `/api/v1/weather_measurement` | **204** (empty body) |
| `POST` | `/api/v1/weather_measurement/bulk` | **202** `{ "accepted": N, "status": "processing" }` |

Single create is idempotent on `reading_date_time` (duplicate → 204). Bulk max is **1000** rows; the write runs in `BulkWriteMeasurementsJob`. Bulk flags (string `"true"` only): `update_records`, `overwrite`.

Required scalar fields (model validations): `reading_date_time`, `barometer_abs`, `barometer_rel`, `gust_speed`, `light`, `humidity`, `temperature`, `rain_day`, `rain_rate`, `uv`, `uvi`, `wind_dir`, `wind_speed`.

Units on the wire: temperature **°C**, barometer **hPa**, wind **m/s**, rain **mm**. The UI converts to °F / inHg / mph / inches.

`heat_index`, `dew_point`, and `wind_chill` are permitted but **not persisted** — dew point and feels-like are computed on the model.

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

Optional nested arrays: `soil[]` and `temp_probes[]` (channels 1–8).

## Data sources

| Card / feature | Source | Job / trigger |
| -------------- | ------ | ------------- |
| Station observations | Measurement API | live insert + Action Cable broadcast |
| **AQI / PM2.5** | **AirNow** HourlyAQObs CSV (`AIRNOW_AQSID`, default Auburn 29th St `840530330047`) | `DownloadAirNowAqiJob` hourly at `:15`; also from `/` if latest is missing, stale (>8h), or not `source: airnow` |
| Forecast | OpenWeather One Call 3.0 | `DownloadOpenWeatherForecastJob` every 10 minutes (and from `/` if older than 1h) |
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
| `MEASUREMENT_API_KEY` | Ingest 401s; empty homepage 500s |
| `LOCATION_LAT` / `LOCATION_LON` | Radar (`ENV.fetch`), wildfire, LibreWXR alerts, several geo jobs |
| `LOCATION_ELEVATION_FT` | Optional; defaults to 416. Reduces station pressure to sea-level / altimeter |
| `OPENWEATHER_API_KEY` | Forecast download |
| `AIRNOW_AQSID` | Optional; defaults to Auburn 29th St |
| `LIBREWXR_API_BASE` | Optional; defaults to `https://api.librewxr.net` |
| `SENTRY_DSN` | Optional; PII on, traces 0.2 in production |
| `SEND_WX` | Must be exactly `true` to upload to WU / PWS / AWEKAS / WeatherCloud / CWOP |
| `SIDEKIQ_USER` / `SIDEKIQ_PASSWORD` | Production `/sidekiq` (open in development) |

## Lint / test

```bash
bin/rubocop
bin/rails test
bin/rails test:system
bin/brakeman
bin/bundler-audit
bin/database_consistency
```

## Pitfalls

- **Empty measurements table → homepage 500.** Seed via the API, not fixtures, in a fresh DB.
- **`Procfile.dev` listener** points at a binary that is not in this repo.
- **Assets are gitignored.** Build (`yarn build` / `yarn build:css`) before serving.
- Forecast model comments still say “every 10 minutes”; cron is every **2** minutes.
