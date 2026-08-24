# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_24_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "almanac_entries", force: :cascade do |t|
    t.datetime "astronomical_dawn_at"
    t.datetime "astronomical_dusk_at"
    t.datetime "civil_dawn_at"
    t.datetime "civil_dusk_at"
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "daylight_delta_seconds"
    t.integer "daylight_seconds"
    t.float "moon_distance_km"
    t.float "moon_illumination_pct"
    t.string "moon_phase"
    t.jsonb "moon_positions_hourly"
    t.datetime "moon_transit_at"
    t.datetime "moonrise_at"
    t.datetime "moonset_at"
    t.datetime "nautical_dawn_at"
    t.datetime "nautical_dusk_at"
    t.datetime "next_equinox_at"
    t.datetime "next_full_moon_at"
    t.datetime "next_new_moon_at"
    t.datetime "next_solstice_at"
    t.datetime "solar_noon_at"
    t.float "sun_distance_km"
    t.float "sun_ecliptic_longitude_deg"
    t.jsonb "sun_positions_hourly"
    t.datetime "sunrise_at"
    t.datetime "sunset_at"
    t.string "timezone", default: "America/Los_Angeles", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_almanac_entries_on_date", unique: true
  end

  create_table "aqis", force: :cascade do |t|
    t.float "co"
    t.datetime "created_at", null: false
    t.integer "epa_aqi"
    t.float "nh3"
    t.float "no"
    t.float "no2"
    t.float "o3"
    t.datetime "observed_at", null: false
    t.float "pm10"
    t.float "pm2_5", null: false
    t.float "so2"
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.index ["observed_at"], name: "index_aqis_on_observed_at", unique: true
    t.index ["source"], name: "index_aqis_on_source"
  end

  create_table "aurora_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "fetched_at", null: false
    t.float "kp", null: false
    t.float "kp_forecast_max_tonight"
    t.float "local_ovation_pct"
    t.string "odds_label"
    t.string "status_label", null: false
    t.datetime "updated_at", null: false
    t.index ["fetched_at"], name: "index_aurora_snapshots_on_fetched_at"
  end

  create_table "earthquakes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "depth", null: false
    t.float "distance", null: false
    t.datetime "eventtime", null: false
    t.datetime "last_updated", null: false
    t.float "lat", null: false
    t.float "lon", null: false
    t.float "magnitude", null: false
    t.string "place", null: false
    t.boolean "revised", default: false, null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.string "usgs_id", null: false
    t.index ["eventtime"], name: "index_earthquakes_on_eventtime"
    t.index ["usgs_id"], name: "index_earthquakes_on_usgs_id", unique: true
  end

  create_table "forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "forecast", null: false
    t.string "interval", default: "daily", null: false
    t.datetime "updated_at", null: false
    t.index ["interval", "created_at"], name: "index_forecasts_on_interval_and_created_at", order: { created_at: :desc }
  end

  create_table "iss_passes", force: :cascade do |t|
    t.datetime "aos_at", null: false
    t.float "aos_az", null: false
    t.datetime "created_at", null: false
    t.integer "duration_s", null: false
    t.datetime "fetched_at", null: false
    t.datetime "los_at", null: false
    t.float "los_az", null: false
    t.float "max_el", null: false
    t.float "max_el_az", null: false
    t.datetime "updated_at", null: false
    t.boolean "visible", default: false, null: false
    t.index ["aos_at"], name: "index_iss_passes_on_aos_at"
    t.index ["visible", "aos_at"], name: "index_iss_passes_on_visible_and_aos_at"
  end

  create_table "planet_nights", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.jsonb "planets", default: [], null: false
    t.string "timezone", default: "America/Los_Angeles", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_planet_nights_on_date", unique: true
  end

  create_table "records", force: :cascade do |t|
    t.integer "consecutive_dry_days"
    t.date "consecutive_dry_start_date"
    t.integer "consecutive_rain_days"
    t.date "consecutive_rain_start_date"
    t.datetime "created_at", null: false
    t.float "highest_apparent_temp"
    t.datetime "highest_apparent_temp_at"
    t.float "highest_daily_rain"
    t.date "highest_daily_rain_date"
    t.float "highest_dew_point"
    t.datetime "highest_dew_point_at"
    t.float "highest_heat_index"
    t.datetime "highest_heat_index_at"
    t.integer "highest_humidity"
    t.datetime "highest_humidity_at"
    t.float "highest_pressure"
    t.datetime "highest_pressure_at"
    t.float "highest_rain_rate"
    t.datetime "highest_rain_rate_at"
    t.float "highest_solar"
    t.datetime "highest_solar_at"
    t.float "highest_temp"
    t.datetime "highest_temp_at"
    t.float "highest_wind_run"
    t.date "highest_wind_run_date"
    t.float "largest_pressure_swing"
    t.date "largest_pressure_swing_date"
    t.float "largest_temp_range"
    t.date "largest_temp_range_date"
    t.integer "longest_calm_hours"
    t.datetime "longest_calm_start_at"
    t.float "lowest_apparent_temp"
    t.datetime "lowest_apparent_temp_at"
    t.float "lowest_dew_point"
    t.datetime "lowest_dew_point_at"
    t.integer "lowest_humidity"
    t.datetime "lowest_humidity_at"
    t.float "lowest_pressure"
    t.datetime "lowest_pressure_at"
    t.float "lowest_temp"
    t.datetime "lowest_temp_at"
    t.float "lowest_wind_chill"
    t.datetime "lowest_wind_chill_at"
    t.string "scope", null: false
    t.float "smallest_temp_range"
    t.date "smallest_temp_range_date"
    t.float "strongest_gust"
    t.datetime "strongest_gust_at"
    t.datetime "updated_at", null: false
    t.integer "wettest_month"
    t.float "wettest_month_total"
    t.integer "wettest_month_year"
    t.integer "year"
    t.index ["scope", "year"], name: "index_records_on_scope_and_year", unique: true
  end

  create_table "report_entries", force: :cascade do |t|
    t.float "avg_wind_speed"
    t.float "cool_degree_days"
    t.datetime "created_at", null: false
    t.integer "day", null: false
    t.float "heat_degree_days"
    t.float "high_pressure"
    t.string "high_pressure_time"
    t.float "high_temp"
    t.string "high_temp_time"
    t.float "high_wind_speed"
    t.string "high_wind_time"
    t.integer "hour"
    t.float "low_pressure"
    t.string "low_pressure_time"
    t.float "low_temp"
    t.string "low_temp_time"
    t.float "mean_pressure"
    t.float "mean_temp"
    t.boolean "partial_period", default: false, null: false
    t.float "rain"
    t.bigint "report_id", null: false
    t.datetime "updated_at", null: false
    t.integer "wind_dir"
    t.string "wind_dir_compass"
    t.index ["report_id", "day", "hour"], name: "index_report_entries_on_report_day_hour", unique: true
  end

  create_table "reports", force: :cascade do |t|
    t.float "avg_wind_speed"
    t.datetime "created_at", null: false
    t.integer "dominant_wind_dir"
    t.string "dominant_wind_dir_compass"
    t.integer "month", null: false
    t.float "month_high_pressure"
    t.integer "month_high_pressure_day"
    t.float "month_high_temp"
    t.integer "month_high_temp_day"
    t.integer "month_high_wind_day"
    t.float "month_high_wind_speed"
    t.float "month_low_pressure"
    t.integer "month_low_pressure_day"
    t.float "month_low_temp"
    t.integer "month_low_temp_day"
    t.float "month_mean_pressure"
    t.float "month_mean_temp"
    t.float "total_cool_degree_days"
    t.float "total_heat_degree_days"
    t.float "total_rain"
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["year", "month"], name: "index_reports_on_year_and_month", unique: true
  end

  create_table "weather_measurements", force: :cascade do |t|
    t.float "barometer_abs", null: false
    t.float "barometer_rel", null: false
    t.datetime "created_at", null: false
    t.float "gust_speed", null: false
    t.integer "humidity", null: false
    t.float "light", null: false
    t.float "rain_day", default: 0.0, null: false
    t.float "rain_rate", null: false
    t.datetime "reading_date_time", null: false
    t.jsonb "soil", default: [], null: false
    t.jsonb "temp_probes", default: [], null: false
    t.float "temperature", null: false
    t.datetime "updated_at", null: false
    t.integer "uv", null: false
    t.float "uvi", null: false
    t.integer "wind_dir", null: false
    t.float "wind_speed", null: false
    t.index ["barometer_abs"], name: "index_weather_measurements_on_barometer_abs"
    t.index ["barometer_rel"], name: "index_weather_measurements_on_barometer_rel"
    t.index ["gust_speed"], name: "index_weather_measurements_on_gust_speed"
    t.index ["humidity"], name: "index_weather_measurements_on_humidity"
    t.index ["light"], name: "index_weather_measurements_on_light"
    t.index ["rain_day"], name: "index_weather_measurements_on_rain_day"
    t.index ["rain_rate"], name: "index_weather_measurements_on_rain_rate"
    t.index ["reading_date_time"], name: "index_weather_measurements_on_reading_date_time", unique: true
    t.index ["temperature"], name: "index_weather_measurements_on_temperature"
    t.index ["wind_speed"], name: "index_weather_measurements_on_wind_speed"
  end

  create_table "wildfire_snapshots", force: :cascade do |t|
    t.float "acres"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.float "distance_mi", null: false
    t.string "external_id"
    t.datetime "fetched_at", null: false
    t.float "lat", null: false
    t.float "lon", null: false
    t.string "name"
    t.float "percent_contained"
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["fetched_at"], name: "index_wildfire_snapshots_on_fetched_at"
  end

  add_foreign_key "report_entries", "reports", on_delete: :cascade
end
