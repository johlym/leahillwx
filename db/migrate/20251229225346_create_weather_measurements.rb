class CreateWeatherMeasurements < ActiveRecord::Migration[8.1]
  def change
    create_table :weather_measurements do |t|
      t.datetime :reading_date_time
      t.float :barometer_abs
      t.float :barometer_rel
      t.float :day_max_wind
      t.float :gust_speed
      t.float :light
      t.float :humidity
      t.float :temperature
      t.float :rain_day
      t.float :rain_event
      t.float :rain_rate
      t.float :uv
      t.float :uvi
      t.float :wind_dir
      t.float :wind_speed

      t.timestamps
    end
  end
end
