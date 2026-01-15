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

ActiveRecord::Schema[8.1].define(version: 2026_01_15_014218) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "aqis", force: :cascade do |t|
    t.float "co"
    t.datetime "created_at", null: false
    t.float "nh3"
    t.float "no"
    t.float "no2"
    t.float "o3"
    t.float "pm10"
    t.float "pm2_5"
    t.float "so2"
    t.datetime "updated_at", null: false
  end

  create_table "earthquakes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "depth"
    t.float "distance"
    t.datetime "eventtime"
    t.float "lat"
    t.float "lon"
    t.float "magnitude"
    t.string "place"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "forecast"
    t.datetime "updated_at", null: false
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
    t.float "high_temp"
    t.string "high_temp_time"
    t.float "high_wind_speed"
    t.string "high_wind_time"
    t.integer "hour"
    t.float "low_temp"
    t.string "low_temp_time"
    t.float "mean_temp"
    t.boolean "partial_period", default: false, null: false
    t.float "rain"
    t.bigint "report_id", null: false
    t.datetime "updated_at", null: false
    t.integer "wind_dir"
    t.string "wind_dir_compass"
    t.index ["report_id", "day", "hour"], name: "index_report_entries_on_report_day_hour", unique: true
    t.index ["report_id"], name: "index_report_entries_on_report_id"
  end

  create_table "reports", force: :cascade do |t|
    t.float "avg_wind_speed"
    t.datetime "created_at", null: false
    t.integer "dominant_wind_dir"
    t.string "dominant_wind_dir_compass"
    t.integer "month", null: false
    t.float "month_high_temp"
    t.integer "month_high_temp_day"
    t.integer "month_high_wind_day"
    t.float "month_high_wind_speed"
    t.float "month_low_temp"
    t.integer "month_low_temp_day"
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
    t.float "rain_day", default: 0.0
    t.float "rain_rate", null: false
    t.datetime "reading_date_time", null: false
    t.float "temperature", null: false
    t.datetime "updated_at", null: false
    t.integer "uv", null: false
    t.float "uvi", null: false
    t.integer "wind_dir", null: false
    t.float "wind_speed", null: false
    t.index ["barometer_rel"], name: "index_weather_measurements_on_barometer_rel"
    t.index ["gust_speed"], name: "index_weather_measurements_on_gust_speed"
    t.index ["humidity"], name: "index_weather_measurements_on_humidity"
    t.index ["light"], name: "index_weather_measurements_on_light"
    t.index ["rain_day"], name: "index_weather_measurements_on_rain_day"
    t.index ["rain_rate"], name: "index_weather_measurements_on_rain_rate"
    t.index ["reading_date_time"], name: "index_weather_measurements_on_reading_date_time"
    t.index ["temperature"], name: "index_weather_measurements_on_temperature"
    t.index ["wind_speed"], name: "index_weather_measurements_on_wind_speed"
  end

  add_foreign_key "report_entries", "reports", on_delete: :cascade
end
