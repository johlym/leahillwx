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

ActiveRecord::Schema[8.1].define(version: 2026_01_13_233106) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "forecasts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "forecast"
    t.datetime "updated_at", null: false
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
    t.float "low_temp"
    t.string "low_temp_time"
    t.float "mean_temp"
    t.boolean "partial_day", default: false, null: false
    t.float "rain"
    t.bigint "report_id", null: false
    t.datetime "updated_at", null: false
    t.integer "wind_dir"
    t.string "wind_dir_compass"
    t.index ["report_id", "day"], name: "index_report_entries_on_report_id_and_day", unique: true
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
    t.index ["reading_date_time"], name: "index_weather_measurements_on_reading_date_time"
  end

  add_foreign_key "report_entries", "reports", on_delete: :cascade
end
