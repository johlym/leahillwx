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

ActiveRecord::Schema[8.1].define(version: 2025_12_29_232605) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "weather_measurements", force: :cascade do |t|
    t.float "barometer_abs"
    t.float "barometer_rel"
    t.datetime "created_at", null: false
    t.float "day_max_wind"
    t.float "gust_speed"
    t.integer "humidity"
    t.float "light"
    t.float "rain_day"
    t.float "rain_event"
    t.float "rain_rate"
    t.datetime "reading_date_time"
    t.float "temperature"
    t.datetime "updated_at", null: false
    t.integer "uv"
    t.float "uvi"
    t.integer "wind_dir"
    t.float "wind_speed"
  end
end
