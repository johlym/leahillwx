# AGENTS.md

## Cursor Cloud specific instructions

This is the **lhwx.org** personal weather-station website: a Rails 8 app (Ruby 4.0.1, Node 24) backed by PostgreSQL and Redis, with Sidekiq for background jobs. Data is ingested via the authenticated measurement API (normally from an external Rust `wxlistener`, which is **not** in this repo) and shown on a live dashboard (home, reports, graphs, records, trends, almanac).

### Toolchain
- Ruby and Node are managed by **mise** (`~/.local/bin/mise`), activated in `~/.bashrc`. Interactive shells already have `ruby`, `node`, `bundle`, `yarn` on `PATH`. In non-interactive scripts, run `eval "$(/home/ubuntu/.local/bin/mise activate bash)"` first.
- The update script (run on startup) refreshes gems and JS deps only. It does **not** start services or touch the DB.

### Services (start these yourself each session; they are not auto-started)
- PostgreSQL: `sudo pg_ctlcluster 16 main start` — dev connects via local socket as OS user `ubuntu` (a superuser role already exists). Databases: `leahillwx_development`, `leahillwx_test`.
- Redis: `sudo redis-server --daemonize yes` — required for Sidekiq (`redis://localhost:6379/0`). Action Cable uses the in-process `async` adapter in development, so Redis is only needed for Sidekiq in dev.
- After a fresh DB (or new migrations): `bin/rails db:prepare` (and `bin/rails db:test:prepare` for the test DB).

### Running the app
- Full dev stack is `bin/dev` (Foreman + `Procfile.dev`), but `Procfile.dev` includes a `listener:` process pointing at `../listener/target/release/wxlistener` (the external Rust collector) which does **not** exist here and will fail — start processes individually instead: `bin/rails server` and `bundle exec sidekiq`.
- Frontend assets are built with esbuild + Tailwind; `app/assets/builds/*` is gitignored so build before/while serving: `yarn build` and `yarn build:css` (append `--watch` for live reload).

### Ingesting data (the app needs at least one measurement or the homepage 500s)
- Set `MEASUREMENT_API_KEY` in `.env` (also set `LOCATION_LAT`/`LOCATION_LON`; copy from `env.sample`). The create/bulk endpoints require `Authorization: Bearer <MEASUREMENT_API_KEY>`.
- `POST /api/v1/weather_measurement` with a `weather_measurement` object (see `app/controllers/api/v1/weather_measurements_controller.rb` for permitted fields and `app/models/weather_measurement.rb` for required/validated fields). Returns `204` on success. `/api/v1/weather_measurement/bulk` enqueues a Sidekiq job.

### Lint / test / build (standard commands; see `.github/workflows/ci.yml` and `config/ci.rb`)
- Lint: `bin/rubocop`
- Tests: `bin/rails test` (parallel; needs Postgres + Redis). System tests: `bin/rails test:system` (Chrome is installed at `/usr/local/bin/google-chrome`).
- Security/consistency (CI also runs): `bin/brakeman`, `bin/bundler-audit`, `bin/database_consistency`.
