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

ActiveRecord::Schema[8.1].define(version: 2025_12_30_003013) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "weather_measurements", force: :cascade do |t|
    t.float "barometer_abs", null: false
    t.float "barometer_rel", null: false
    t.datetime "created_at", null: false
    t.float "day_max_wind", null: false
    t.float "gust_speed", null: false
    t.integer "humidity", null: false
    t.float "light", null: false
    t.float "rain_day", null: false
    t.float "rain_event", null: false
    t.float "rain_rate", null: false
    t.datetime "reading_date_time", null: false
    t.float "temperature", null: false
    t.datetime "updated_at", null: false
    t.integer "uv", null: false
    t.float "uvi", null: false
    t.integer "wind_dir", null: false
    t.float "wind_speed", null: false
  end
end
