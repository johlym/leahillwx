class EnforceDatabaseConsistencyConstraints < ActiveRecord::Migration[8.1]
  def up
    # Legacy AQI rows predate observed_at/source; they were OpenWeather pulls.
    safety_assured do
      execute <<~SQL.squish
        UPDATE aqis
        SET observed_at = created_at,
            source = 'openweather'
        WHERE observed_at IS NULL OR source IS NULL
      SQL

      execute <<~SQL.squish
        UPDATE earthquakes
        SET last_updated = COALESCE(last_updated, updated_at, eventtime, created_at)
        WHERE last_updated IS NULL
      SQL
    end

    # Verified no remaining nulls; rain_day already defaults to 0.0.
    safety_assured do
      change_column_null :weather_measurements, :rain_day, false
      change_column_null :forecasts, :forecast, false
      change_column_null :aqis, :pm2_5, false
      change_column_null :aqis, :observed_at, false
      change_column_null :aqis, :source, false
      change_column_null :earthquakes, :magnitude, false
      change_column_null :earthquakes, :place, false
      change_column_null :earthquakes, :eventtime, false
      change_column_null :earthquakes, :last_updated, false
      change_column_null :earthquakes, :url, false
      change_column_null :earthquakes, :lat, false
      change_column_null :earthquakes, :lon, false
      change_column_null :earthquakes, :depth, false
      change_column_null :earthquakes, :distance, false
      change_column_null :earthquakes, :usgs_id, false
      change_column_null :earthquakes, :revised, false

      # Covered by unique index on (report_id, day, hour).
      remove_index :report_entries, name: "index_report_entries_on_report_id"
    end
  end

  def down
    change_column_null :weather_measurements, :rain_day, true
    change_column_null :forecasts, :forecast, true
    change_column_null :aqis, :pm2_5, true
    change_column_null :aqis, :observed_at, true
    change_column_null :aqis, :source, true
    change_column_null :earthquakes, :magnitude, true
    change_column_null :earthquakes, :place, true
    change_column_null :earthquakes, :eventtime, true
    change_column_null :earthquakes, :last_updated, true
    change_column_null :earthquakes, :url, true
    change_column_null :earthquakes, :lat, true
    change_column_null :earthquakes, :lon, true
    change_column_null :earthquakes, :depth, true
    change_column_null :earthquakes, :distance, true
    change_column_null :earthquakes, :usgs_id, true
    change_column_null :earthquakes, :revised, true

    add_index :report_entries, :report_id, name: "index_report_entries_on_report_id"
  end
end
